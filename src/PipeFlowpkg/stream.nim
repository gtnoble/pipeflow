import strutils
import sequtils
import tables
import deques

type
    ScalarSample* = float
    VectorSample* = seq[ScalarSample]
    SignalStream*[T] = object
        readSample*: proc (sample: var T): bool
        headers*: Headers
    SignalStreamVector* = SignalStream[VectorSample] 
    SignalStreamScalar* = SignalStream[ScalarSample]
    HeaderEntry = object
        key: string
        value: string
    Headers* = Table[string, string]


func parse_signal_line(line: string): seq[ScalarSample] =
    result = line.split(',').map(parseFloat)

func is_header_line(line: string): bool =
    result = line.contains('=')

func parse_header_line(line: string): HeaderEntry =
    var split_header_line = line.split('=')
    result = HeaderEntry(key: split_header_line[0], value: split_header_line[1])

proc initSignalStream*(file: File): SignalStreamVector =
    var 
        line: string
        headers: Headers
        next_sample: seq[ScalarSample]
        noMoreSamples: bool = false

    while readLine(file, line) and is_header_line(line):
        let header = parse_header_line(line)
        headers[header.key] = header.value
    
    next_sample = parse_signal_line(line)

    proc readSample(sample: var seq[ScalarSample]): bool =
        if noMoreSamples:
            return false
        sample = next_sample
        if readLine(file, line):
            next_sample = parse_signal_line(line)
            return true
        else:
            noMoreSamples = true
            return true
    
    return SignalStreamVector(readSample: readSample, headers: headers)

proc initSignalStream*(signal: SignalStreamVector, field_index:Natural): SignalStreamScalar =
    
    proc readSample(sample: var ScalarSample): bool =
        var 
            vectorSample: VectorSample
        if signal.readSample(vectorSample):
            if field_index < vectorSample.len():
                sample = vectorSample[field_index]
            else:
                sample = NaN
            result = true
        else:
            result = false

    result = SignalStreamScalar(readSample: readSample, headers: signal.headers)

proc toSignalStreamVector*(signal: SignalStreamScalar): SignalStreamVector =

    proc readSample(sample: var VectorSample): bool =
        var
            scalarSample: ScalarSample
        if signal.readSample(scalarSample):
            sample = @[scalarSample]
            result = true
        else:
            result = false
    
    result = SignalStreamVector(readSample: readSample, headers: signal.headers)

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

proc write*(file: File, signal: SignalStreamVector) =
    for k, v in signal.headers.pairs():
        file.writeLine(k & "=" & v)
    for sample in eachSample(signal):
        file.writeLine(sample.join(","))

proc write*(file: File, signal: SignalStreamScalar) =
    write(file, toSignalStreamVector(signal))
