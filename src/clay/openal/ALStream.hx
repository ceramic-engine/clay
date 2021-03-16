package clay.openal;

import clay.Types;
import clay.audio.AudioSource;
import clay.audio.AudioInstance;
import clay.audio.AudioErrorReason;
import clay.buffers.Uint8Array;

import clay.openal.OpenALAudio;
import clay.openal.AL;

@:allow(clay.openal.OpenALAudio)
class ALStream extends ALSound {

    /** The sound buffer names */
    public var buffers:Array<ALuint>;

    /** The sound buffer data  */
    public var bufferData:Uint8Array;

    /** Remaining buffers to play */
    public var buffersLeft:Int = 0;

    var duration:Float = 0.0;

    public function new(audio:OpenALAudio, source:AudioSource, instance:AudioInstance) {

        super(audio, source, instance);
        
        duration = source.getDuration();

    }

    override function init() {

        Log.debug('Audio / alsource: $alsource');

        buffers = [for (i in 0...source.streamBufferCount) 0];
        buffers = AL.genBuffers(source.streamBufferCount, buffers);
        bufferData = new Uint8Array(source.streamBufferLength);

        ensureNoError(GEN_BUFFERS);

        instance.dataSeek(0);

        initQueue();

    }

/// ALSound

    override function destroy() {

        Log.debug('Audio / destroy ' + source.data.id);

        ensureNoError(PRE_SOURCE_STOP);

        AL.sourceStop(alsource);

        ensureNoError(PRE_FLUSH_QUEUE);

        flushQueue();

        ensureNoError(POST_FLUSH_QUEUE);

        // Order is important here, destroy source first
        super.destroy();

        while (buffers.length > 0) {
            var b = buffers.pop();
            AL.deleteBuffer(b);
            ensureNoError(DELETE_BUFFER);
        }

        buffers = null;
        bufferData.buffer = null;
        bufferData = null;

    }

    override function getPosition() {

        return currentTime + AL.getSourcef(alsource, AL.SEC_OFFSET);

    }

    override function setPosition(time:Float):Void {

        var playing = stateIs(AL.PLAYING);

        // Stop lets go of buffers
        AL.sourceStop(alsource);
        flushQueue();

        // Clamp between 0 and duration
        time = (time < 0) ? 0 : ((time > duration) ? duration : time);
        currentTime = time;

        var samples = source.secondsToBytes(time);

        instance.dataSeek(samples);

        #if clay_debug_audio_verbose
        Log.debug('Audio / position $_time, seek to $_samples');
        #end

        // Make sure queue is refilled from the new position
        initQueue();

        if (playing) {
            AL.sourcePlay(alsource);
        }

    }

/// Internal

    inline function stateToString() {
        return switch getState() {
            case AL.INITIAL: 'INITIAL';
            case AL.PLAYING: 'PLAYING';
            case AL.PAUSED: 'PAUSED';
            case AL.STOPPED: 'STOPPED';
            case _: 'UNKNOWN';
        }
    }

    inline function getState() {
        return AL.getSourcei(alsource, AL.SOURCE_STATE);
    }

    inline function stateIs(state:Int) {
        return state == getState();
    }

/// Queue management

    function initQueue(start:Int = -1) {

        if (start != -1) instance.dataSeek(start);

        for (i in 0...source.streamBufferCount) {
            fillBuffer(buffers[i]);
            AL.sourceQueueBuffer(alsource, buffers[i]);
            ensureNoError(QUEUE_BUFFER);
        }

        ensureNoError(INIT_QUEUE);

        buffersLeft = source.streamBufferCount;

    }

    function flushQueue() {

        var queued = AL.getSourcei(alsource, AL.BUFFERS_QUEUED);

        Log.debug('Audio / flushing queued buffers ' + queued);

        for(i in 0 ... queued) {
            AL.sourceUnqueueBuffer(alsource);
        }

        ensureNoError(FLUSH_QUEUE);

    }

    var _dataGetResult:Array<Int> = [0,0];

    /**
     * Returns the result of the data request, which may not get any data,
     * and which may have reached the end of the data source itself.
     */
    function fillBuffer(buffer:ALuint):Array<Int> {

        // Try to read the data into the buffer, the -1 means "from current"
        var read = instance.dataGet(bufferData, -1, source.streamBufferLength, _dataGetResult);
        var amount = read[0];

        #if clay_debug_audio_verbose
        Log.debug('Audio / bufferData / $buffer / format: $alformat / freq: ${source.data.rate} / size: ${read[0]}');
        #end

        ensureNoError(PRE_FILL_BUFFER);

        if (amount > 0) {
            AL.bufferData(buffer, alformat, source.data.rate, bufferData.buffer, bufferData.byteOffset, amount);
        }

        ensureNoError(POST_FILL_BUFFER);

        return _dataGetResult;

    }
    
/// ALStream

    override function tick(delta:Float):Void {

        // instance.tick(); (not needed, there is nothing to do in instance.tick())

        if (!stateIs(AL.PLAYING)) {
            return;
        }

        var stillStreaming = true;

        #if clay_debug_audio_verbose
        Log.debug('Audio / alsource:$alsource ${state_str()} ${position_of()}/$duration | ${source.seconds_to_bytes(position_of())}/${source.data.length} | ${buffers_left} ');
        #end

        var processedBuffers = AL.getSourcei(alsource, AL.BUFFERS_PROCESSED);

        ensureNoError(QUERY_PROCESSED_BUFFERS);

        // Disallow large or invalid values since we are using a while loop
        if (processedBuffers > source.streamBufferCount) processedBuffers = source.streamBufferCount;
        while (processedBuffers > 0) {

            var buffer:ALuint = AL.sourceUnqueueBuffer(alsource);

            ensureNoError(SOURCE_UNQUEUE_BUFFER);

            var bufferSize = AL.getBufferi(buffer, AL.SIZE);

            currentTime += source.bytesToSeconds(bufferSize);

            #if clay_debug_audio_verbose
            Log.debug('Audio / buffer was done / ${_buffer} / size(${bufferSize}) / currentTime(${currentTime}) / pos(${position_of()})');
            #end

            // Repopulate this empty buffer,
            // if it succeeds, then throw it back at the end of
            // the queue list to keep playing.
            var dataState = fillBuffer(buffer);
            var dataAmount = dataState[0];
            var dataEnded = (dataState[1] == 1);
            
            // If not looping, we shouldn't queue up the buffer again
            var skipQueue = (!looping && dataEnded);
                
            // Make sure the time resets correctly when looping
            var timeIsAtEnd = (getPosition() >= duration);
            // If the time has run over, we reset the timer if looping
            if (timeIsAtEnd && looping) {
                currentTime = 0;
                audio.emitAudioEvent(END, instance.handle);
            }

            #if clay_debug_audio_verbose
            Log.debug('Audio / data has ended? $dataEnded');
            Log.debug('Audio / at end? $timeIsAtEnd ${getPosition()} >= $duration');
            #end

            // If the data was complete,
            // we reset the source data to 0, 
            // and try get some more, otherwise 
            // we just wait for our queued buffers to run out
            if (dataEnded) {

                if (looping) {

                    #if clay_debug_audio_verbose
                    Log.debug('Audio / data ended while looping, seek audio to 0');
                    #end
                
                    instance.dataSeek(0);

                    // If looping, and we just reset the data source,
                    // if the amount we got back was zero, it means this buffer
                    // is empty, and needs to be filled.
                    if (dataAmount == 0) {
                        #if clay_debug_audio_verbose
                        Log.debug('Audio / buffer was empty due to end of stream, refilling');
                        #end
                        fillBuffer(buffer);
                    }
                
                }
                else {
                
                    buffersLeft--;
                    #if clay_debug_audio_verbose
                    Log.debug('Audio / running down buffers, one more down, ${buffersLeft} to go');
                    #end
                    if (buffersLeft < 0) {
                        stillStreaming = false;
                    }
                    else {
                        skipQueue = false;
                    }
                
                }

            }

            if (!skipQueue) {
                AL.sourceQueueBuffer(alsource, buffer);
                #if clay_debug_audio_verbose
                Log.debug('Audio / requeued buffer ' + buffer);
                #end
            }

            processedBuffers--;

        }

        if (!stillStreaming) {
            AL.sourceStop(alsource);
        }

    }

}
