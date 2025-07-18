build:
	./bootstrap.sh
	./wheel-build.sh dist
	./wheel-check.sh dist
	./wheel-test.sh  dist

lint:
	codespell
	ruff check -qn
	ruff format -qn --diff
	shellcheck *.sh
	yamllint .github/

clean:
	$(RM) -r package/METADATA
	$(RM) -r package/LICENSE*
	$(RM) -r package/build
	$(RM) -r package/source
	$(RM) -r package/workdir
	$(RM) -r package/install
	$(RM) -r package/*.egg-info
	$(RM) -r .*_cache
