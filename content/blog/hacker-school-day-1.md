---
title: hacker school, day 1
date: "2014-09-02T19:55:00"
tags: [hacker school]
---

So I'm finally starting [Hacker School](https://www.hackerschool.com/). Today
was partly an orientation day, and I spent a while meeting people and stuff,
but eventually settled down to work.

For my first project, I decided to work on an IRC bouncer in
[Rust](http://rust-lang.org/). I've wanted a decent IRC bouncer for a while -
I'm currently using [ZNC](http://wiki.znc.in/ZNC), which is the only really
usable one I've found, but it doesn't really handle disconnection well. I'd
like to be able to just close my laptop and go, and actually get all of the
messages I missed when I open it back up. The problem is that if you don't
explicitly disconnect the IRC client, the bouncer has no way of knowing when
you stopped receiving messages, so messages in that timeout window tend to
just get dropped, which makes it quite difficult to keep up with
conversations.

The solution I'm going to try is to split the bouncer into two parts, a client
and a server. The server still runs as usual, but you run a bouncer client
locally, and that is what you connect to with your IRC client. The bouncer
client then talks to the bouncer server using a different protocol which
allows you to sync unread messages reliably.

The first problem that I ran into is that there doesn't appear to be a
fully-featured IRC library for Rust yet (in particular, one that can handle
being a server as well as a client), so... the first step is obviously to
write one! I've done this before [in Lua](https://github.com/doy/luairc), so I
don't think this should be an insurmountable obstacle. We'll see how accurate
that assessment is this week, I suppose.
