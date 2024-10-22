it('should NOT fail on warning', () => {
    // behavior can be configured in setupFilesAfterEnv.ts
    console.warn("This is okay!");
})

it('should fail on error', () => {
    console.error("This test should fail!");
})

it('should NOT fail on expected error', () => {
    // given
    jest.spyOn(console, 'error').mockImplementation();
    const expectedErrorMessage = "This test should NOT fail!";

    // when
    console.error(expectedErrorMessage)

    // then
    expect(console.error).toHaveBeenCalledWith(expectedErrorMessage)
})