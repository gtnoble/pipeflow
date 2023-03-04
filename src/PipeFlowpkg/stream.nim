import strutils
import sequtils
import tables
import deques

type
    ScalarSample*[T] = T
    VectorSample*[T] = seq[ScalarSample[T]]
    SignalStream*[T] = object
        readSample*: proc (sample: var T): bool
        headers*: Headers
    SignalStreamVector*[T] = SignalStream[VectorSample[T]] 
    SignalStreamScalar*[T] = SignalStream[ScalarSample[T]]
    HeaderEntry = object
        key: string
        value: string
    Headers* = Table[string, string]
    Transformer*[T, U] = proc (input: T): U
    Filter*[T] = Transformer[T, T]


func parse_signal_line(line: string): VectorSample[float] =
    result = line.split(',').map(parseFloat)

func is_header_line(line: string): bool =
    result = line.contains('=')

func parse_header_line(line: string): HeaderEntry =
    var split_header_line = line.split('=')
    result = HeaderEntry(key: split_header_line[0], value: split_header_line[1])

proc initSignalStream*(file: File): SignalStreamVector[float] =
    var 
        line: string
        headers: Headers
        next_sample: seq[ScalarSample[float]]
        noMoreSamples: bool = false

    while readLine(file, line) and is_header_line(line):
        let header = parse_header_line(line)
        headers[header.key] = header.value
    
    next_sample = parse_signal_line(line)

    proc readSample(sample: var VectorSample[float]): bool =
        if noMoreSamples:
            return false
        sample = next_sample
        if readLine(file, line):
            next_sample = parse_signal_line(line)
            return true
        else:
            noMoreSamples = true
            return true
    
    return SignalStreamVector[float](readSample: readSample, headers: headers)


proc initSignalStream*[T](samples: openArray[T], headers: Headers): SignalStream[T] = 
    var sampleQueue = samples.toDeque()
    
    proc readSample(sample: var T): bool =
        if sampleQueue.len() != 0:
            sample = sampleQueue.popFirst()
            result = true
        else:
            result = false
    
    result = SignalStream[T](readSample: readSample, headers: headers)

iterator eachSample*[T](signal: SignalStream[T]): T =
    var 
        sample: T
    while signal.readSample(sample):
        yield sample

proc eachSample*[T](signal: SignalStream[T]): seq[T] =
    var 
        samples: seq[T]
    for sample in eachSample(signal):
        samples.add(sample)
    result = samples

proc transform*[T, U](signal: SignalStream[T], transformer: Transformer[T, U]): SignalStream[U] =
    let 
        signal: SignalStream[T] = signal
        transformer: Transformer[T, U] = transformer

    proc readSample[U](filteredSample: var U): bool =
        var sample: T
        if signal.readSample(sample):
            filteredSample = transformer(sample)
            result = true
        else:
            result = false
    
    result = SignalStream[U](readSample: readSample, headers: signal.headers)

proc toSignalStreamVector*[T](signal: SignalStreamScalar[T]): SignalStreamVector[T] =

    proc toVector(scalar: ScalarSample[T]): VectorSample[T] =
        result = @[ScalarSample]

    result = transform(signal, toVector)

proc initSignalStream*[T](signal: SignalStreamVector[T], field_index:Natural): SignalStreamScalar[T] =
    
    proc getElement(vectorSample: VectorSample[T]): ScalarSample[T] =
        if field_index < vectorSample.len():
            result = vectorSample[field_index]
        else:
            result = NaN

    result = transform(signal, getElement)

proc write*(file: File, signal: SignalStreamVector) =
    for k, v in signal.headers.pairs():
        file.writeLine(k & "=" & v)
    for sample in eachSample(signal):
        file.writeLine(sample.join(","))

proc write*(file: File, signal: SignalStreamScalar) =
    write(file, toSignalStreamVector(signal))
