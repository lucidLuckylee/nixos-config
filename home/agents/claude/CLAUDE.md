# Code
- Only make changes that are directly requested or clearly necessary. A bug fix does not need surrounding cleanup; a one-shot operation does not need a helper.
- Do the simplest thing that works. No abstractions, feature flags, or backwards-compatibility shims when you can just change the code.
- Do not add error handling, fallbacks, or validation for cases that cannot happen. Validate at system boundaries only.
- Write code that reads like the surrounding code: match its comment density, naming, and idiom. Comment only where the logic is not self-evident.
- Do not add docstrings, comments, or type annotations to code you did not change.
- If you find a pre-existing bug or unrelated issue, leave it and mention it as a follow-up.
- Add tests only where the task asks for them or the repo already tests this kind of change. Do not turn scratch checks into permanent test files.
- Edit files surgically rather than rewriting them. Delete temporary files you created. Do not create documentation files unless asked.
