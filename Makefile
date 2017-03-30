# Add: --define:jsonob_no_exhaustive to turn off warnings about unused properties from jsonob
NIM_OPTS=--parallelBuild:1 --define:nimOldSplit --debuginfo --linedir:on
RELEASE_OPTS=--opt:size
APP_NAME=dup
BIN_DIR=build
SRC_DIR=dup
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

$(BIN_DIR)/ds: ./docker_socket/docker_socket.nim
	nim c $(NIM_OPTS) --out:$@ $<

ds: $(BIN_DIR)/ds
	@$<

$(BIN_DIR)/tar: ./docker_socket/tar.nim
	nim c $(NIM_OPTS) --out:$@ $<

tar: $(BIN_DIR)/tar
	@$<

$(BIN_DIR)/ad: ./docker_socket/async_docker.nim
	nim c $(NIM_OPTS) --out:$@ $<

ad: $(BIN_DIR)/ad
	@$<

.PHONY: all clean run release linux test ds tar ad
