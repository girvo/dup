NIM_OPTS=--parallelBuild:1 --define:nimOldSplit
RELEASE_OPTS=--opt:size
APP_NAME=dup
BIN_DIR=build
SRC_DIR=src
TEST_DIR=test

all: clean $(BIN_DIR)/$(APP_NAME)

clean:
	rm -f build/dup build/*.tar.gz build/linux/dup && \
	mkdir -p build build/linux

run: $(BIN_DIR)/$(APP_NAME)
	@$<

macos: release
	strip - $(BIN_DIR)/$(APP_NAME)

linux:
	docker build -t dup:latest .
	docker run --rm -v $(CURDIR)/build/linux/:/build dup:latest cp /dup/build/dup /build/dup

release: clean
	nim c $(NIM_OPTS) --define:release $(RELEASE_OPTS) --out:$(BIN_DIR)/$(APP_NAME) $(SRC_DIR)/$(APP_NAME)

$(BIN_DIR)/$(APP_NAME): $(wildcard $SRC_DIR/**/*.nim)
	nim c $(NIM_OPTS) --out:$(BIN_DIR)/$(APP_NAME) $(SRC_DIR)/$(APP_NAME)

# Executes the (compiled, dependent) test runner
test: ./test/runner
	@$<

./test/runner: $(wildcard ./**/*.nim)
	nim c -x:on $(TEST_DIR)/runner

.PHONY: all clean run release linux test
