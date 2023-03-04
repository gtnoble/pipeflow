# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import deques
import tables

import PipeFlowpkg/stream

let scalarTestValues: array[8, ScalarSample[float]] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
let vectorWrappedScalarTestValues: array[8, VectorSample[float]] = [@[1.0], @[2.0], @[3.0], @[4.0], @[5.0], @[6.0], @[7.0], @[8.0]]

suite "Compare Stream Input / Output":

  setup:
    var headers: Headers 
    let scalarSignal: SignalStreamScalar[float] = initSignalStream(scalarTestValues, headers)

  test "Scalar input and output are the same":
    check(scalarSignal.eachSample() == scalarTestValues)

suite "Test Stream File I/O":

  setup:
    let file: File = open("./tests/test_data/scalar_test_data.signal")
    let vectorSignal: SignalStreamVector[float] = initSignalStream(file)
    let testOutputFilePath: string = "./tests/test_data/stream_write_test.signal"
  
  teardown:
    close(file)

  test "Test Vector file stream reading":
    check vectorSignal.eachSample() == vectorWrappedScalarTestValues

  test "Test Scalar file stream reading":
    let scalarSignal: SignalStreamScalar[float] = initSignalStream(vectorSignal, 0)
    check(scalarSignal.eachSample() == scalarTestValues)
  
  test "Test header reading":
    check(vectorSignal.headers["herp"] == "derp")

  test "Test vector stream writing":
    var testOutputFile: File = open(testOutputFilePath, fmWrite)
    testOutputFile.write(vectorSignal)
    close(testOutputFile)

  test "Test reading written file":
    var testOutputFile = open(testOutputFilePath, fmRead)
    var newVectorSignal = initSignalStream(testOutputFile)
    check newVectorSignal.eachSample() == vectorWrappedScalarTestValues
    check newVectorSignal.headers["herp"] == "derp"


  

