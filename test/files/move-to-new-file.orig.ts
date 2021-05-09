import { testFunc } from "./test-func";

function functionToMove() {
	testFunc();
}

export function main() {
	testFunc();
    functionToMove();
}

main();
