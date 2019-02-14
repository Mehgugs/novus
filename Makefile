.PHONY: docs
docs:
	rm -r docs/*
	ldoc -c ./config.ld ./lua/novus
