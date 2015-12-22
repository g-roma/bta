BENDING THE ARC
===============
Copyright (c) 2015 Gerard Roma, Jason Freeman, Anna Xambó


Application Start
-----------------

Before starting the Bending the Arc application, you will need to install:

* SuperCollider 3.7alpha1

* SuperCollider Extensions SC3plugins (for the Tartini class): <Link>
The SC3plugins folder needs to be installed in the directory ``Library/Application Support/SuperCollider/Extensions/``

Make sure to restart SuperCollider or recompile the class library (Language > Recompile Class Library) before starting the program.


Usage
-----

The application has three parts divided into three patches, which need to be executed sequentially over time: 

1) corpus_recorder.scd
2) corpus_index.scd
3) player.scd

Before executing the code, configure the path for recordings and index files. Make sure the server is not running before starting each script. Ideally restart the interpreter each time.


Recorder
--------

Configure the recordings directory. You can start the application by opening `corpus_recorder.scd` on the SuperCollider IDE. Next:

1) Wait to press start until the meter displays the channel signals from mic input; 
2) Set threshold level of recording; 
3) Press start to start recording; 
4) Press stop to stop recording or wait until total number of available buffers have been recorded.

Indexer
-------
Set "baseName" to the path and base file name for index files. Two files will be created by appending "_pitch.dat" and "_usable".dat. Run the script and watch for progress in the post window.

Player
-------
Configure the baseName used for indexing and run. The patch will be listening for MIDI notes. Sliders can be set before playing notes for configuring the parameters of two layers.

License
-------

MIT


