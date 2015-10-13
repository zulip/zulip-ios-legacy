Developer Setup Instructions
----------------------------

These instructions may work for many versions of OS X, but for posterity, let it be known that these instructions were written by starting from a completely new install of OX X 10.10.4.

First, I downloaded Xcode 6.4 from the App Store

Specifically Build 6E35b updated on June 30, 2015

To install git, you need to open a terminal and run
`sudo git`
The sudo part is necessary to agree to the Xcode/iOS license.

After you have set up git, clone the repo.

git clone git@git.zulip.net:eng/humbug-iphone.git --recursive
TODO PUT REPO URI HERE

The recursive is important, as it fetches all the git submodules too.

`git clone <something>`

on the stable branch, we haven’t yet started using Cocoapods.

if you want to build the unstable version, you’ll need to start from branch

TODO PUT BRANCH HERE

If you forgot `--recursive` when cloning this repo, from the git checkout directory, get all the git submodules:
`git submodule update —init`

Then, open the Xcode project file.
`open Zulip.xcodeproj`

If this is your first iOS app, Xcode will ask to install additional components. Go ahead and do that.

Also go ahead and enable developer mode when it asks.

Crashlytics
-----------

Crashlytics running on builds has been disabled, as part of the open sourcing effort.

A note on the Message Views
---------------------------

Historically, we wanted to target iOS 6.0, and also be able to show users messages with the same formatting (or as close as possible) as that which they would see on the website. We thought about including a markdown renderer, as this would make a lot of sense for performance reasons, but we do enough server-side modifications to regular markdown that this is probably not ideal. UIWebViews proved too slow (even if we cached the rendered image version of the message cell), so we eventually settled on using DTCoreText. However, this dependency can be a little finicky, so (as of August 2015), we are trying to migrate to iOS 7+, where we can depend on the HTML input feature for NSAttributedStrings.
