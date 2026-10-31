.PHONY: test build publish install uninstall clean markdown install-hooks

PACLET_NAME = MaximilienTirard/HTMLPatterns

# publish needs PUBLISH_DEST (an scp destination for the archive) and
# PUBLISH_REBUILD_URL (fetched to rebuild the paclet site); set them in local.mk
-include local.mk

build: clean
	@wolframscript -code 'Needs["PacletTools`"]; r = PacletTools`PacletBuild["."]; If[FailureQ[r], Print["Build failed: ", r]; Exit[1]]; Print["Built ", FileNameTake[Last[r]["PacletArchive"]], " (", Round[QuantityMagnitude[Last[r]["TotalTime"], "Seconds"], 0.1], "s)"]; Exit[0]'

publish: build
	@test -n "$(PUBLISH_DEST)" -a -n "$(PUBLISH_REBUILD_URL)" || { echo "Set PUBLISH_DEST and PUBLISH_REBUILD_URL in local.mk"; exit 1; }
	@archive=$$(ls build/*.paclet | head -1); \
	echo "Uploading $$(basename $$archive) -> $(PUBLISH_DEST)/"; \
	scp -q "$$archive" "$(PUBLISH_DEST)/" && \
	echo "Triggering paclet site rebuild..." && \
	curl -fsS -o /dev/null "$(PUBLISH_REBUILD_URL)" && \
	echo "Published."

install: build
	@archive=$$(ls build/*.paclet | head -1); \
	echo "Uninstalling any existing $(PACLET_NAME)..."; \
	wolframscript -code 'PacletUninstall["$(PACLET_NAME)"];' > /dev/null; \
	echo "Installing $$(basename $$archive)..."; \
	wolframscript -code 'r = PacletInstall["'$$archive'", ForceVersionInstall -> True]; If[FailureQ[r], Print["Install failed: ", r]; Exit[1]]; PacletManager`RebuildPacletData[]; Print["Installed ", r["Name"], " ", r["Version"], " (paclet data rebuilt)"]; Exit[0]'

uninstall:
	@wolframscript -code 'r = PacletUninstall["$(PACLET_NAME)"]; Print["Uninstalled ", Length[Flatten[{r}]], " paclet(s)"]'

test:
	@wolframscript -file Tests/run_tests.wls

clean:
	@rm -rf build

# Documentation.md/ holds each doc page as `wltext show` prints it, at its doc URI
# tail: paclet:MaximilienTirard/HTMLPatterns/ref/X is Documentation.md/ref/X.md
markdown:
	@wltext mirror . Documentation.md
	@scripts/add-example-init.sh Documentation.md

install-hooks:
	git config core.hooksPath scripts/githooks
	@echo "Installed git hooks (core.hooksPath -> scripts/githooks)."
