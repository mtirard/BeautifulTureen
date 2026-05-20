.PHONY: test build publish clean

WREL_USER   ?= mtirard
WREL_HOST   ?= wrel-resources.wolfram.com
WREL_PACLETS = /home/usr2/tonya/wrel-resources-server/paclet-site/Paclets
WREL_REBUILD = http://$(WREL_HOST)/wl/paclet-site/rebuild

build: clean
	@wolframscript -code 'Needs["PacletTools`"]; r = PacletTools`PacletBuild["."]; If[FailureQ[r], Print["Build failed: ", r]; Exit[1]]; Print["Built ", FileNameTake[Last[r]["PacletArchive"]], " (", Round[QuantityMagnitude[Last[r]["TotalTime"], "Seconds"], 0.1], "s)"]; Exit[0]'

publish: build
	@archive=$$(ls build/*.paclet | head -1); \
	echo "Uploading $$(basename $$archive) -> $(WREL_USER)@$(WREL_HOST):$(WREL_PACLETS)/"; \
	scp -q "$$archive" "$(WREL_USER)@$(WREL_HOST):$(WREL_PACLETS)/" && \
	echo "Triggering paclet site rebuild..." && \
	curl -fsS -o /dev/null "$(WREL_REBUILD)" && \
	echo "Published."

test:
	wolframscript -code 'report = TestReport["Tests/Tests-BeautifulTureen.wlt"]; Print[report["TestsSucceededCount"], " passed, ", report["TestsFailedCount"], " failed"]; If[report["TestsFailedCount"] > 0, Exit[1]]'

clean:
	@rm -rf build
