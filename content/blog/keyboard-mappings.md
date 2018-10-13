---
title: keyboard mappings
date: "2013-11-02T20:54:00"
tags: [configuration, keyboard]
---

So I was at the [Pittsburgh Perl Workshop](http://pghpw.org/ppw2013/), and
[John Anderson](https://twitter.com/genehack) gave a
[talk](http://pghpw.org/ppw2013/talk/5084) about his personal configuration
setup. It motivated me to spend quite a bit of time going over [my own
configuration](https://github.com/doy/conf), but in particular it reminded me
that I had been wanting to adjust my keyboard for a while now. My pinkies have
been getting tired more quickly lately, and I'm fairly sure this is in large
part because of how often I have to use the Shift and Control keys. I do all
of my work on laptops, so it would be pretty inconvenient to get an external
keyboard, so I decided to actually put some effort into looking at ways to
modify my existing keyboard to be easier to type on.

## Control

One of the first things I did was read up ways to avoid finger stress. As it
turns out, this is especially common in the Emacs community (since so many of
their keyboard shortcuts rely on weird modifier key combinations), and there's
even a [project](http://ergoemacs.org/) dedicated to making Emacs more
ergonomic. One of the things that they do mention is that contrary to popular
wisdom, [mapping Caps Lock to Control really isn't a very good
solution](http://ergoemacs.org/emacs/swap_CapsLock_Ctrl.html). They recommend
swapping Control and Alt instead, since Control is used far more often, and
you can press the Alt key with your thumb, which is a much stronger finger.

To do this, I added this to my `.Xmodmap`:

    clear control
    clear mod1
    keycode 37 Alt_L Meta_L
    keycode 64 Control_L
    keycode 105 Alt_R Meta_R
    keycode 108 Control_R
    add control = Control_L Control_R
    add mod1 = Alt_L Alt_R Meta_L Meta_R

## Shift

The next thing I started thinking about was how to reduce the usage of the
Shift keys. I do a lot of programming, which uses punctuation characters quite
a bit, and so I started
[wondering](https://twitter.com/doyster/status/388138795557978112) if swapping
the shifted and unshifted number row would be a good idea. As it turns out,
[Brock Wilcox](https://twitter.com/awwaiid) did this [quite a while
ago](http://thelackthereof.org/Keyboard_Number-Symbol_Swap), and he liked it a
lot. Using that as a place to start, I came up with [this
script](https://github.com/doy/conf/blob/master/bin/toggle_numkeys):

    if xmodmap -pk | grep -q '(1).*(exclam).*(1).*(exclam)'; then
    xmodmap -e 'keycode 10 = exclam 1'
        xmodmap -e 'keycode 11 = at 2'
        xmodmap -e 'keycode 12 = numbersign 3'
        xmodmap -e 'keycode 13 = dollar 4'
        xmodmap -e 'keycode 14 = percent 5'
        xmodmap -e 'keycode 15 = asciicircum 6'
        xmodmap -e 'keycode 16 = ampersand 7'
        xmodmap -e 'keycode 17 = asterisk 8'
        xmodmap -e 'keycode 18 = parenleft 9'
        xmodmap -e 'keycode 19 = parenright 0'
        xmodmap -e 'keycode 20 = underscore minus'
        xmodmap -e 'keycode 34 = braceleft bracketleft'
        xmodmap -e 'keycode 35 = braceright bracketright'
        xmodmap -e 'keycode 49 = asciitilde grave'
        xmodmap -e 'keycode 51 = bar backslash'
    else
    xmodmap -e 'keycode 10 = 1 exclam'
        xmodmap -e 'keycode 11 = 2 at'
        xmodmap -e 'keycode 12 = 3 numbersign'
        xmodmap -e 'keycode 13 = 4 dollar'
        xmodmap -e 'keycode 14 = 5 percent'
        xmodmap -e 'keycode 15 = 6 asciicircum'
        xmodmap -e 'keycode 16 = 7 ampersand'
        xmodmap -e 'keycode 17 = 8 asterisk'
        xmodmap -e 'keycode 18 = 9 parenleft'
        xmodmap -e 'keycode 19 = 0 parenright'
        xmodmap -e 'keycode 20 = minus underscore'
        xmodmap -e 'keycode 34 = bracketleft braceleft'
        xmodmap -e 'keycode 35 = bracketright braceright'
        xmodmap -e 'keycode 49 = grave asciitilde'
        xmodmap -e 'keycode 51 = backslash bar'
    fi

I bound the script to pressing both Shift keys at once as Brock recommended
(using xbindkeys):

    "toggle_numkeys"
      Shift + Shift_R

    "toggle_numkeys"
      Shift + Shift_L

and also set it to run when I logged into X. Note that this also maps a few
other things - besides just the number row, it also makes tilde, underscore,
left and right brace, and pipe into the unshifted characters for their
respective keys. Underscore was the biggest win, I think - typing
`$variable_names_with_lots_of_words_in_them` was always a pretty big strain.

Again as Brock pointed out, I had to remap the keys in some other applications
to make them stay usable. Strangely enough, both i3 and Firefox continued to
work (I have `Mod4+1`, etc mapped to switching desktops in i3, and Firefox
uses `Alt+1`, etc for tab switching). Not really sure what's going on there. I
did have to add some remappings for the hint mode in
[Pentadactyl](http://5digits.org/pentadactyl/) though:

    set hintkeys=")!@#$%^&*("

Zsh, readline, and vim also required remapping `)` to `0`, since I use the `0`
command a lot. Here's from vimrc:

    nmap <silent>) 0

and zshrc:

    bindkey -M vicmd ')' vi-digit-or-beginning-of-line

and inputrc:

    ")": beginning-of-line

I couldn't figure out how to get the number keys in choose-window mode in tmux
to remap (if anyone has any clues, let me know), but I did rebind the
copy-mode command:

    bind { copy-mode

So far, I've been using this setup for a little over two weeks, and I'm liking
it a lot. My fingers are noticeably less tired, and I feel like my typing
speed while programming is quite a bit faster. A lot of things feel more
natural too - for instance, `my ($foo_bar, $baz) = @_;` is now typed entirely
without pressing the Shift key, which feels much better. One thing that does
still bother me is that `(:` now requires one shifted and one non-shifted key,
which makes it harder to type, but I'm fairly sure that overall I use `;` more
than `:`, so I don't think switching that is worthwhile.

In addition to these keyboard remappings, I also remapped a bunch of things in
vim to use fewer keystrokes, but I'll talk about that in a future post.
