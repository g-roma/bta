// Granular Player

// Basic interface for playing two granular layers
// and a sampler layer from indexed corpus.
// Trigger notes with MIDI keyboard, adust grain sizes,
// duraiton and amplitudes with sliders


(
var initFunc, playFunc, loadBufferFunc;
var baseName = "/path/to/base"; // includes path and base file name
var existsBase = File.exists(baseName++"_usable.dat");
var usableFiles, pitchDict, buffers;
var server, options;
var kNUM_BUFFERS = 4096;
var onFunc, offFunc, oscFuncs;
var graphicsServer = NetAddr("127.0.0.1", 7000);
var window;
var amp1SliderTitle, amp1Slider, dur1SliderTitle, dur1Slider, density1SliderTitle, density1Slider;
var amp2SliderTitle, amp2Slider, dur2SliderTitle, dur2Slider, density2SliderTitle, density2Slider;
var amp3SliderTitle, amp3Slider, dur3SliderTitle, dur3Slider;
var amp1box, dur1box, dens1box;
var amp2box, dur2box, dens2box;
var amp3box, dur3box;
var numBuffersLoaded = 0;



loadBufferFunc = {|i|
	var f = usableFiles[i];
	var fileId = PathName(f).fileNameWithoutExtension;
	if (File.exists(f)){
		buffers[fileId] = Buffer.readChannel(server, f, channels:0, action:{
			numBuffersLoaded = numBuffersLoaded +1;
			postln(f);
			post(numBuffersLoaded);
			post("/");postln(usableFiles.size);
			if( i < (usableFiles.size - 1)){loadBufferFunc.value(i+1)};
		})
	}
	{
			postln(f++" not found");
		    pitchDict.keys().do({|k|
			    pitchDict[k].do({|x|
				  if(x[0]==fileId){
					pitchDict[k].remove(x);
		          }
		        })
		    });
		    if( i < (usableFiles.size - 1)){loadBufferFunc.value(i+1)};
	}
};


initFunc = {

		if(existsBase==false)
	       {"Warning: this analyzed sounds directory does not exist".postln}
	       {postln("Analyzed sounds will be played from"++baseName)};

	SynthDef(\bta_player,{|pos = 0, buf,
		amp1 = 0.5, amp2 = 0.5, amp3 = 0.5,
		dur1 = 0.05, dur2 = 2, dur3 = 1,
		density1 = 20, density2 = 0.5|
		var pitch, dur,tmp;
		var layer1, layer2;
		layer1 = amp1 * TGrains.ar(2, Dust.kr(density1), buf, 1, pos, dur1, 0, 0.1, 2)!2;
		layer2 = amp2 * TGrains.ar(2, Dust.kr(density2), buf, 1, pos, dur2, 0, 0.1, 2)!2;
		Out.ar(0, layer1 + layer2);
	}).store;

	SynthDef(\bta_player_oneshot,{|pos = 0,  buf,
		amp = 0.5, dur = 0.05|
		var env = EnvGen.ar(Env.new([0,1,0],[0.01,dur-0.01], \welch));
		var pb =  env * amp * PlayBuf.ar(1, buf, 1, 1, pos, 0)!2;
		Out.ar(0, pb);
	}).store;

	usableFiles = File.open(
		baseName++"_usable.dat","rt"
	).readAllString.compile.value;
	usableFiles = usableFiles.as(Array);

	pitchDict = File.open(
		baseName++"_pitch.dat","rt"
	).readAllString.compile.value;

	buffers = Dictionary.new;
	loadBufferFunc.value(0);
	MIDIClient.init;
	MIDIIn.connectAll;

};

playFunc = {
	var synths = Dictionary.new;
	var nSynths = 10;
	var player = KeyPlayer(\k);
	127.do({|i| synths.put(i,[])});

	window = Window.new("Player", Rect(400, 400, 280, 470));

	// layer 1, granular synth, small grain
	//amp1
	amp1SliderTitle = StaticText(window, Rect(10, 10, 200, 10));
	amp1SliderTitle.string = "Amplitude 1";
	amp1Slider = Slider(window, Rect(10, 30, 200, 20))
    .value_(0.5)
    .action_({amp1box.value_(amp1Slider.value)});
	amp1box = NumberBox(window, Rect(220, 30, 50, 20));
	amp1box.value = amp1Slider.value;
	//dur1
	dur1SliderTitle = StaticText(window, Rect(10, 60, 200, 10));
	dur1SliderTitle.string = "Duration 1";
	dur1Slider = Slider(window, Rect(10, 80, 200, 20))
    .value_(0.1)
    .action_({dur1box.value_(dur1Slider.value)});
	dur1box = NumberBox(window, Rect(220, 80, 50, 20));
	dur1box.value = dur1Slider.value;
	//density1
	density1SliderTitle = StaticText(window, Rect(10, 110, 200, 10));
	density1SliderTitle.string = "Density 1";
	density1Slider = Slider(window, Rect(10, 130, 200, 20))
    .value_(10)
    .action_({dens1box.value_(density1Slider.value)});
	dens1box = NumberBox(window, Rect(220, 130, 50, 20));
	dens1box.value = density1Slider.value;

	// layer 2, granular synth, larger grain
	//amp2
	amp2SliderTitle = StaticText(window, Rect(10, 180, 200, 10));
	amp2SliderTitle.string = "Amplitude 2";
	amp2Slider = Slider(window, Rect(10, 200, 200, 20))
    .value_(0.5)
    .action_({amp2box.value_(amp2Slider.value)});
	amp2box = NumberBox(window, Rect(220, 200, 50, 20));
	amp2box.value = amp2Slider.value;
	//dur2
	dur2SliderTitle = StaticText(window, Rect(10, 230, 200, 10));
	dur2SliderTitle.string = "Duration 2";
	dur2Slider = Slider(window, Rect(10, 250, 200, 20))
    .value_(0.5)
    .action_({dur2box.value_(dur2Slider.value)});
	dur2box = NumberBox(window, Rect(220, 250, 50, 20));
	dur2box.value = dur2Slider.value;
	//1x density2
	density2SliderTitle = StaticText(window, Rect(10, 280, 200, 10));
	density2SliderTitle.string = "Density 2";
	density2Slider = Slider(window, Rect(10, 300, 200, 20))
    .value_(0.1)
    .action_({dens2box.value_(density2Slider.value)});
	dens2box = NumberBox(window, Rect(220, 300, 50, 20));
	dens2box.value = density2Slider.value;

	// layer 3, one-shot
	//amp3
	amp3SliderTitle = StaticText(window, Rect(10, 350, 200, 10));
	amp3SliderTitle.string = "Amplitude 3";
	amp3Slider = Slider(window, Rect(10, 370, 200, 20))
    .value_(0.5)
    .action_({amp3box.value_(amp3Slider.value)});
	amp3box = NumberBox(window, Rect(220, 370, 50, 20));
	amp3box.value = amp3Slider.value;
	//dur3
	dur3SliderTitle = StaticText(window, Rect(10, 400, 200, 10));
	dur3SliderTitle.string = "Duration 3";
	dur3Slider = Slider(window, Rect(10, 420, 200, 20))
    .value_(0.5)
    .action_({dur3box.value_(dur3Slider.value)});
	dur3box = NumberBox(window, Rect(220, 420, 50, 20));
	dur3box.value = dur3Slider.value;

	window.front;

	onFunc = MIDIFunc.noteOn({ |veloc, num, chan, src|
		if (pitchDict[num].size > 0){
			pitchDict[num].wrapExtend(nSynths).do({|grain|
				var buf = buffers[grain[0]];
				var pos = grain[1];
				{synths[num] = synths[num].add(
						Synth(\bta_player, [\pos,pos,\buf, buf,
						\amp1, amp1Slider.value,
						\amp2, amp2Slider.value,
						\dur1, dur1Slider.value,
						\dur2, ControlSpec(0,3).map(dur2Slider.value),
						\density1, ControlSpec(1,50).map(density1Slider.value),
						\density2, ControlSpec(0.1,5).map(density2Slider.value)],
						server)
				);
				}.defer;
			});
			{
				var grain = pitchDict[num].choose;
				var oneShotBuf = buffers[grain[0]];
				grain.postln;
				oneShotBuf.postln;

				synths[num] = synths[num].add(
					Synth(\bta_player_oneshot,
						[\pos, oneShotBuf.numFrames.rand,
						\buf, oneShotBuf,
						\amp, amp3Slider.value,
						\dur, ControlSpec(1,10).map(dur3Slider.value)],
						server
			))}.defer;
		};
	});

	offFunc = MIDIFunc.noteOff({ |veloc, num, chan, src|
		    synths[num].do({|synth| synth.free});
		    synths.removeAt(num);
	});

};

server = Server.new(\player,NetAddr("localhost",59000));
options = ServerOptions.new;
options.numInputBusChannels = 8;
options.numBuffers = kNUM_BUFFERS;
server.options = options;

server.waitForBoot({
	initFunc.value;
	2.wait;
	playFunc.value;
});
)