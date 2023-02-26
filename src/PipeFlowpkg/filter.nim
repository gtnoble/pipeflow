import stream
import deques
import math

type
    Filter*[T] = proc (input: T): T

proc applyFilter*[T](signal: SignalStream[T], filter: Filter[T]): SignalStream[T] =

    proc readSample[T](filteredSample: var T): bool =
        var sample: T
        if signal.readSample(sample):
            filteredSample = filter(sample)
            result = true
        else:
            result = false
    
    result = SignalStream(readSample: readSample, headers: signal.headers)

proc movingAverage*(initialBuffer: openArray[ScalarSample]): Filter[ScalarSample] =
    var
        buffer: Deque[ScalarSample] = initialBuffer.toDeque()
        moving_sum: ScalarSample = sum(initialBuffer)

    proc filter(input: ScalarSample): ScalarSample =
        moving_sum -= buffer.popLast()
        buffer.addFirst(input)
        moving_sum += input
        result = moving_sum / ScalarSample(buffer.len())
    
    result = filter

    