#Include %A_LineFile%\..\Assert.ahk

Test("AssertEqual passes on equal strings", () => AssertEqual("abc", "a" "bc"))
Test("AssertEqual passes on equal numbers", () => AssertEqual(4, 2 * 2))
Test("AssertEqual reports expected and actual", AssertEqualReportsMismatch)

AssertEqualReportsMismatch() {
    try {
        AssertEqual(1, 2)
    } catch Error as e {
        AssertEqual(1, e.Expected)
        AssertEqual(2, e.Actual)
        return
    }
    throw Error("AssertEqual did not throw")
}
