# Unreal Engine 3 Aircraft Mod

This is an aircraft physics mod for UE3 based on https://github.com/gasgiant/Aircraft-Physics.
The original Unity project is written in C#. This is a re-implementation of it in UnrealScript
for Unreal Engine 3. There are a lot of workarounds that are put in place in an attempt to make
the project work, but it still has a lot of work to do to make it actually playable.

I started this project originally in 2021 and have archived it recently in GitHub in hopes
of finalizing the implementation and getting it to work on a satisfactory level finally.

# Issues / TODO

There are currently some issues with the physics, mainly instability and being able to take off.
These are due to different approaches to handling physics in Unity vs. UE3 among other things.

# License

```
MIT License

Copyright (c) 2024 Tuomo Kriikkula

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

**NOTE:** This software contains code adapted and re-written from
https://github.com/gasgiant/Aircraft-Physics. The relevant license can be found in
[ThirdPartyLicenses/LICENSE-Aircraft-Physics](ThirdPartyLicenses/LICENSE-Aircraft-Physics).
