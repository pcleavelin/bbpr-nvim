## With great UI comes great bad UX
The aim of this project is to remove the need to actually use the BitBucket web UI to view/comment/approve pull requests.

### Current Features
* List Pull Requests in current repo
* View all modified files in Pull Request along with their diff

### TODO
* Add comments to files
* Ability to Approve/Decline Pull Requests
* Don't rely on global variables to store BitBucket credentials

## How to use
Before you can start using the plugin, you need to set some global variables in
your vim config:

    - `bbpr_bb_user`
    - `bbpr_bb_password`

You will also need to have [telescope](https://github.com/nvim-telescope/telescope.nvim) installed.

#### NOTE:
It's not ideal to have these in the global scope, as any plugin you have installed
will be able to access them.

If you don't have 2-factor authentication enabled for your BitBucket account, you
can just use your username & password for these variables (I think, haven't tested though).
However I strongly recommend to create an app-password that only has read (for now)
access for pull requests. You can do that [here](https://bitbucket.org/account/settings/app-passwords/new)

Once you have setup your credentials, all you need to do is run the command
```
:Bbpr
```

This will open up a list of Pull Requests to choose from. After selecting a PR
a new tab will open up with the PR description and a list of files to look at.
Selecting a file will open up the changes for that file as well as inline comments
from the PR.
