# Code Guideline
This contribution guideline is tentative,
to keep the program style doesn't really
change much.
Feel free to tell if there's something that doesn't fit
about this or any inconsistency that we can discuss later on.

**Indentation**: **2 spaces**

- please avoid using tabs at any costs

**Method Call**: recommended for certain condition
  
  - *Accessors*: **no parentheses**
  - *Directives*: **no parentheses**
    
    Explanation: directives are looks like function,
                 but they changes the flow of the ruby itself.
    
  - *Others*
    - no following non-alphanumeric
      recommended to use the parentheses
    - with suffixing non-alphanumeric
      - no arguments: not-so-recommended to use
      - with arguments: **use parentheses**

**Hash Mapping**:

  - *Key*: try to use comparable ones first,
           avoid using inconsistent key mapping if possible.
           use `nil` for default value,
           use `default_value=` for variant by key duplication.
  - *Value*: single-typed if possible

**Semi-colons**: unless there are any flow modifier,
  use it to indicate end-of-statement.
  *Don't use it on comments, long-string comments, or such.*
  

more to come.

# Commit Guideline
Try to use three-letter tag for any commits that you've done.

- `[FIX]` for bugfixes and such
- `[ADD]` for newly implemented feature
- `[PLN]` to prepare a feature plan that can be marked as TODO later on
- `[REV]` for reverting things that shouldn't be done now
- `[GIT]` *for modifying the git-core of this repo*

# Warning
Please note that this guideline **only applies to Ruby language**.
If you want to contribute something on the ported language repo,
you can take a look at the other repo too.

But don't forget that this repo **specifically for Ruby**.
