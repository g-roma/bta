(
// Corpus indexer

// Creates two index files:
// 1 - A list of the usable files
// (files that are too small or have no playable grains are discarded)
// 2 - A dictionary that indexes midi keys to an array with [file id, position in seconds]

// Run this script from the terminal: /path/to/sclang corpus_index.scd

var baseName = "/path/to/base"; // includes path and base file name
var recordingsDir = "/path/to/recordings/";
var existsDir = File.exists(recordingsDir);
var grainSize = 22050; // smallest pitched unit size in samples
var maxPitchRange = 2;// maximum range for accteptable grain in midi notes
var backupStep = 100; // number of audio files to analyze per backup index file
var pitchDict, usableFiles, pitchIndexFile, usableIndexFile;
var server, options;
var analyze, store, allFiles, filesToProcess;


analyze = {|fileNum|
	var descBuffer, fileName, fileId;
	fileNum.post;"/".post;allFiles.size.postln;
	if (fileNum < allFiles.size){
		if (fileNum >0 && (fileNum % backupStep == 0)){store.value(fileNum)};
		fileName = allFiles[fileNum].fullPath;
		fileId = PathName(fileName).fileNameWithoutExtension;
		// 1 sec @ 44.1khz, 5 channels, 16bit (2 bytes)
		if (File.fileSize(fileName) > (44100 * 5 * 2)){
			try {
				descBuffer = Buffer.readChannel(server,fileName,channels:2, action: {|buf|
					buf.loadToFloatArray(action: {|pitchArr|
						var nGrains;
						nGrains = ceil(pitchArr.size / grainSize);
						fileName.postln;
						nGrains.post;" grains".postln;
						nGrains.do({|idx|
							var gStart, gEnd, gCenter,
							gPitches, gNotes,
							gNote, gRange;
							gStart = (idx * grainSize).asInt;
							gEnd = min((idx + 1) * grainSize, pitchArr.size).asInt;
							gCenter = round(gStart + ((gEnd - gStart)/2));
							gPitches = pitchArr[gStart..gEnd];
							gNotes = gPitches.collect({|p| p * 127});
							gNote = round(gNotes.sort[gNotes.size/2]); // median
							gRange = maxItem(gPitches) - minItem(gPitches);
							if (gRange < maxPitchRange){
								usableFiles.add(fileName);
								pitchDict[gNote] = pitchDict[gNote].add(
									[fileId, gCenter / 44100.0]);
							};
						});
						analyze.value(fileNum + 1);
				})});
			}
			// Except
			{
				postln("Error processing"+fileName);
				analyze.value(fileNum + 1);
			}
		}{
			postln("Too small, skipping");
			analyze.value(fileNum + 1);
		}
	}{
		store.value(fileNum);
	}
};

store = {|num|
	var fname = baseName;
	postln("Storing"+fname++num);
	if(filesToProcess>0){fname = fname++"_"++num++"remaining"};
	pitchIndexFile = File(fname ++ num++"_pitch.dat", "wt");
	pitchIndexFile.write( pitchDict.asCompileString);
	pitchIndexFile.close;
	usableIndexFile = File(fname ++ num++"_usable.dat", "wt");
	usableIndexFile.write( usableFiles.asCompileString);
	usableIndexFile.close;
};

allFiles = PathName(recordingsDir).files;
filesToProcess =0;

pitchDict = Dictionary.new;
127.do({|i| pitchDict.put(i, []) });
usableFiles = Set.new;

options = ServerOptions.new;
options.numBuffers = 100000;

server = Server.new(\indexer,NetAddr("localhost",58000));
server.options = options;

server.waitForBoot({
	if(existsDir==false){"Warning: this recordings directory does not exist".postln}{postln("Recordings will be stored at"++recordingsDir)};
	analyze.value(0);
});

)