NIM_OPTS=--parallelBuild:1
APP_NAME=dup
BIN_DIR=build
SRC_DIR=src

all: clean $(BIN_DIR)/$(APP_NAME)

clean-linux:
	rm -rf build/linux/linux

clean:
	rm -f build/dup build/*.tar.gz build/linux/dup && \
	mkdir -p build build/linux

run: $(BIN_DIR)/$(APP_NAME)
	@$<

linux:
	docker build -t dup:latest . && \
	docker run --rm -v $(CURDIR)/build/linux/:/build/ dup:latest make && \
	rm -r build/linux/linux

$(BIN_DIR)/$(APP_NAME): $(wildcard $SRC_DIR/**/*.nim)
	nim c $(NIM_OPTS) --out:../$(BIN_DIR)/$(APP_NAME) $(SRC_DIR)/$(APP_NAME)

.PHONY: all clean run
