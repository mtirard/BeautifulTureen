.PHONY: test build clean

build:
	wolframscript -code 'Needs["PacletTools`"]; result = PacletTools`PacletBuild["."]; Print[result]; If[FailureQ[result], Exit[1]]'

test:
	wolframscript -code 'report = TestReport["Tests/Tests-BeautifulTureen.wlt"]; Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"]; If[report["TestsFailedCount"] > 0, Exit[1]]'

clean:
	rm -rf build
