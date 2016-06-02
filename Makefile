NIM_OPTS=--parallelBuild:1
APP_NAME=dup
BIN_DIR=build
SRC_DIR=src
TEST_DIR=tests

all: clean $(BIN_DIR)/$(APP_NAME)

tar: $(wildcard ./tar/*.nim)
	@nim c --run tar/tar

test: $(wildcard $SRC_DIR/**/*.nim)
	@nim c --run -w:off --hints:off tests/runner.nim

clean:
	rm -f build/dup build/*.tar.gz build/linux/dup && \
	mkdir -p build build/linux

run: $(BIN_DIR)/$(APP_NAME)
	@$<

linux:
	docker build -t dup:latest .
	docker run --rm -v $(CURDIR)/build/linux/:/build dup:latest cp /dup/build/dup /build/dup

$(BIN_DIR)/$(APP_NAME): $(wildcard $SRC_DIR/**/*.nim)
	nim c $(NIM_OPTS) --out:../$(BIN_DIR)/$(APP_NAME) $(SRC_DIR)/$(APP_NAME)

.PHONY: all clean run
