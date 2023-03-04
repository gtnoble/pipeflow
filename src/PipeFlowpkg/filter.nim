import stream
import deques
import math

type
    Number = float or int
    FirLinearFilter[T] = object
        feedForwardCoefficients: seq[T]
        feedForwardInitialBuffer: seq[T]
    IirLinearFilter[T] = object
        feedForwardCoefficients: seq[T]
        feedForwardInitialBuffer: seq[T]
        feedBackCoefficients: seq[T]
        feedBackInitialBuffer: seq[T]

proc applyFilter*[T](signal: SignalStream[T], filter: Filter[T]): SignalStream[T] =
    result = transform(signal, filter)

proc movingAverage*[T: Number](signal: SignalStreamScalar[T], initialBuffer: openArray[T]): SignalStreamScalar[T] =
    var
        buffer: Deque[T] = initialBuffer.toDeque()
        moving_sum: T = sum(initialBuffer)

    proc filter(input: T): T =
        moving_sum -= buffer.popLast()
        buffer.addFirst(input)
        moving_sum += input
        result = moving_sum / T(buffer.len())
    
    result = applyFilter(signal, filter)

proc initFirLinearFilter*[T: Number](feedForwardCoefficients: openArray[T]): FirLinearFilter[T] =
    let feedForwardInitialBuffer: seq[T] = newSeq[T](feedForwardCoefficients.len())
    result = FirLinearFilter(feedForwardCoefficients=feedForwardCoefficients, feedForwardInitialBuffer=feedForwardInitialBuffer)

proc initIirLinearFilter*[T: Number](feedForwardCoefficients: openArray[T], feedBackCoefficients: openArray[T]): IirLinearFilter[T] =
    let 
        feedBackInitialBuffer: seq[T] = newSeq[T](feedBackCoefficients.len())
        feedForwardInitialBuffer: seq[T] = newSeq[T](feedForwardCoefficients.len())

    result = IirLinearFilter[T](
        feedForwardCoefficients=feedForwardCoefficients,
        feedForwardInitialBuffer=feedForwardInitialBuffer,
        feedBackCoefficients=feedBackCoefficients,
        feedBackInitialBuffer=feedBackInitialBuffer
    )