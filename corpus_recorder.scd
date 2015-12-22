// Corpus Recorder

// Monitors input for audio above a certain threshold.
// Starts recorders for channels above threshold.
// Recorder stores audio and descriptors to disk,
// and sends descriptors to a set of OSCFuncs that forward to desired port.

// "fakeCorpus" mode allows testing with existing audio instead of live mics.

// Run this script from the terminal: /path/to/sclang corpus_recorder.scd

(
// these two determine the amount of memory allocated for buffers
// and the number of recordings that can be made in one session
var kNUM_BUFFERS = 8192;
var kBUFFER_SIZE = 65536/4;

// offset for file Id
var nextBuf = 0;


var monitorDef, recorderDef;
var bufferPool, curentBuffers;

var recordingsDir = "/path/to/recordings/";
var existsDir = File.exists(recordingsDir);
var recorderSynths, monitorSynths;
var server = Server.local, options;
var graphicsServer = NetAddr("127.0.0.1", 7000);

var window, startButton, startButtonTitle, meter, thresholdSlider, thresholdSliderTitle, thresholdSliderValue, micMonitor, micMonitorTitle, micNumTitle, bufferRecNumTitle, bufferRecNum;
var startFunc, initFunc;

var fakeCorpus = "/path/to/fakecorpus.wav";
var fakeCorpusBuffer;

var oscFuncs;

initFunc = {
	bufferPool = Array.fill(kNUM_BUFFERS, {|i|
		Buffer.alloc(s, kBUFFER_SIZE, 5);
	});
	curentBuffers = Array.fill(8,nil);
	oscFuncs = Array.new;

	//fakeCorpusBuffer = Buffer.readChannel(server, fakeCorpus, channels: [0]); // uncomment for fakeCorpus mode

	if(existsDir==false){"Warning: this recordings directory does not exist".postln}{postln("Recordings will be stored at"++recordingsDir)};

	monitorDef = SynthDef(\monitor, {|threshold = 0.005, channel = 0|
		var in, amp;
		//in = PlayBuf.ar(1, fakeCorpusBuffer, BufRateScale.kr(fakeCorpusBuffer)); // uncomment for fakeCorpus mode
		in = SoundIn.ar(channel); // comment out for fakeCorpus mode
		amp = Lag.kr(Amplitude.kr(in, 0.1, 2),1);
		//Poll.kr(Impulse.kr(20),amp,\amp); // monitor for adjusting threshold, comment out in prod
		SendTrig.kr(amp-threshold, channel,1); // start
		SendTrig.kr(threshold-amp, channel,0); // stop
	}).add;

	recorderDef = SynthDef(\recorder, {|buf, channel = 0|
		var in, out, freq, hasFreq, pitch, voiced, loud, centroid;
		var recorder, chain;
		var sendingPulse;
		var debugSynth;
		//in = PlayBuf.ar(1, fakeCorpusBuffer, BufRateScale.kr(fakeCorpusBuffer));  // uncomment for fakeCorpus mode
		in = SoundIn.ar(channel); // comment out for fakeCorpus mode
		chain = FFT(LocalBuf(2048), in);
		centroid = K2A.ar(SpecCentroid.kr(chain)/(4.0*2048));
		# freq, hasFreq = Tartini.kr(in);
		loud = K2A.ar(Loudness.kr(chain)/64.0);
		voiced = K2A.ar((hasFreq-0.9)*10);
		pitch = K2A.ar(freq.cpsmidi / 127.0);
		recorder = DiskOut.ar(buf,[in, loud, pitch, voiced, centroid]);
		sendingPulse = Impulse.kr(10); // 10 messages per sec
		SendReply.kr(sendingPulse,'/pitch', pitch, channel);
		SendReply.kr(sendingPulse,'/loud', loud, channel);
		SendReply.kr(sendingPulse,'/voiced', voiced, channel);
		SendReply.kr(sendingPulse,'/centroid', centroid, channel);
		debugSynth = 0 * SinOsc.ar((pitch * 127).midicps); // change multiplier to check pitch detection
		//Out.ar(0,(in + debugSynth )); // uncomment for debugging
	}).add;

	window = Window.new("Recorder", Rect(0, 400, 320, 500));
	//8x input mic meters start/stop
	meter = ServerMeterView(server, window, 0@0, 8, 0);

	//1x global threshold slider
	thresholdSliderTitle = StaticText(window, Rect(10, 230, 200, 10));
	thresholdSliderTitle.string = "Threshold Rec Level";
	thresholdSlider = Slider(window, Rect(10, 250, 200, 20))
	.value_(0.5)
	.action_({
		monitorSynths.do({|synth|
			synth.set(\threshold, ControlSpec(0.005, 0.1, \exp).map(thresholdSlider.value))
		});
	});

	//8x input mic recording on/off
	micMonitorTitle = StaticText(window, Rect(10, 290, 200, 10));
	micMonitorTitle.string = "Mic Rec Monitor";
	micMonitor = Array.fill(8,{|i|
		StaticText(window, Rect(30*i+20, 310, 20, 20));
	});
	micNumTitle = Array.fill(8,{|i|
		StaticText(window, Rect(30*i+25, 330, 20, 20));
	});
	for (0, 7, { arg i;
		micMonitor[i].string = "off";
		micMonitor[i].background = Color.grey;
		micNumTitle[i].string = i;
	});

	//1x global start button
	startButtonTitle = StaticText(window, Rect(10, 295, 100, 160));
	startButtonTitle.string = "Recording";
	startButton = Button(window.view, Rect(10, 390, 100, 50));
	startButton.states = [["start",Color.blue],["stop", Color.red]];
	startButton.action = {|b| if(b.value ==1){ startFunc.value}{
		monitorSynths.do({|synth| synth.free});
		recorderSynths.do({|synth| synth.free});
		oscFuncs.do({|func| func.free});
		8.do({|i| {micMonitor[i].background = Color.red; }.defer;
			{micMonitor[i].string = "off";}.defer;
		});
	}};

	//1x global number of recorded buffers
	bufferRecNumTitle = StaticText(window, Rect(10, 460, 200, 10));
	bufferRecNumTitle.string = "# Recorded Buffer: ";
	bufferRecNum = StaticText(window, Rect(130, 460, 200, 10));
	bufferRecNum.string = nextBuf + "out of" + kNUM_BUFFERS + "buffers...";
	window.front;
};

startFunc = {

	recorderSynths = Array.fill(8,{|i|
		Synth.newPaused(\recorder, [\channel, i])
	});

	monitorSynths = Array.fill(8,{|i|
		Synth.new(\monitor, [\channel, i])
	});

	oscFuncs.add(OSCFunc({ |msg|
		var channel = msg[2];
		var value = msg[3];
		if(value==0){
			recorderSynths[channel].run(0);
			if (curentBuffers[channel].notNil){
				postln("closing"++curentBuffers[channel]);
				curentBuffers[channel].close;
			};
			{micMonitor[channel].background = Color.red;}.defer;
			{micMonitor[channel].string = "off";}.defer;
		}
		{
			var buf = bufferPool[nextBuf];
			var fname = Date.getDate.rawSeconds.asString.replace(".","")++channel.asString;
			buf.write(recordingsDir ++ fname ++ ".wav", "wav", "int16", 0, 0, true);
			recorderSynths[channel].set(\buf, buf);
			recorderSynths[channel].run(1);
			curentBuffers[channel] = buf;
			nextBuf = nextBuf + 1;
			{micMonitor[channel].background = Color.green;}.defer;
			{micMonitor[channel].string = "on";}.defer;
			{bufferRecNum.string = nextBuf + "out of" +
				kNUM_BUFFERS + "buffers...";}.defer;
		};
		graphicsServer.sendMsg("/aud/"++(channel+1)++"/active",value);
		("channel" + channel + " : " + ["stop", "start"].at(value)).postln;
	}, '/tr', server.addr));


	// send OSC to graphics server
	oscFuncs.add(OSCFunc({ |msg|
		var channel = msg[2];
		var value = msg[3];
		("/aud/"++(channel+1)++"/pitch"++value).postln;
		graphicsServer.sendMsg("/aud/"++(channel+1)++"/pitch",value);
	}, '/pitch'));

	oscFuncs.add(OSCFunc({ |msg|
		var channel = msg[2];
		var value = msg[3];
		("/aud/"++(channel+1)++"/loud"++value).postln;
		graphicsServer.sendMsg("/aud/"++(channel+1)++"/loud",value);
	}, '/loud'));

	oscFuncs.add(OSCFunc({ |msg|
		var channel = msg[2];
		var value = msg[3];
		("/aud/"++(channel+1)++"/voiced"++value).postln;
		graphicsServer.sendMsg("/aud/"++(channel+1)++"/voiced",value);
	}, '/voiced'));

	oscFuncs.add(OSCFunc({ |msg|
		var channel = msg[2];
		var value = msg[3];
		("/aud/"++(channel+1)++"/centroid"++value).postln;
		graphicsServer.sendMsg("/aud/"++(channel+1)++"/centroid",value);
	}, '/centroid'));
};

options = ServerOptions.new;
options.numInputBusChannels = 8;
options.numBuffers = kNUM_BUFFERS+10;
server.options = options;
server.waitForBoot({initFunc.value});

)
