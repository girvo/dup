NIM_OPTS=--parallelBuild:1
APP_NAME=dup
BIN_DIR=build
SRC_DIR=src

all: clean $(BIN_DIR)/$(APP_NAME)

clean:
	rm -rf build && \
	mkdir -p build

run: $(BIN_DIR)/$(APP_NAME)
	@$<

$(BIN_DIR)/$(APP_NAME): $(wildcard $SRC_DIR/**/*.nim)
	nim c $(NIM_OPTS) --out:../$(BIN_DIR)/$(APP_NAME) $(SRC_DIR)/$(APP_NAME)

.PHONY: all clean run
