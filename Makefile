.PHONY: test

test:
	wolframscript -code 'report = TestReport["Tests/Tests-BeautifulTureen.wlt"]; Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"]; If[report["TestsFailedCount"] > 0, Exit[1]]'
