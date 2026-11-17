# Tiller requirements, as written by the owner

This file contains the requirements word for word, in the order of the messages. Typos are kept. A note after a quote says where a later message changed it. The current decisions are in [PRD.md](PRD.md).

## 1. Requirements drawing (`docs/diagrams_drawing_tiller.tldraw`, page "rough designs")

> definitions
> we have some terms/glossary items/primitives in the app to help us stay consistent
>
> screen: the actual physical screen
>
> desktop: the digital desktop - all available space minus the menu bar and minus any visible dock. if the either (or both) the menu bar or dock are hidden, then the desktop includes that space.
>
> workspace: the largest possible area that can be addressed/used for windows in our app. this is the root, and is a singleton. it tracks and manages all other primitives/entities in our Tiller. no containers can pop outside/layout outside of the workspace
>
> containers: a container is a division of the workspace. it can contain many app windows. they can be created and destroyed. They are never nested. they can only exist in the workspace, not outside of it and not in other primitives or entities.
>
> windows: app windows/dialogs/pop-ups etc
>
> container layouts: built-in (in v1) sets of containers within the workspace. e.g.
>
> must have
>
> full screen (1 container),
>
> vertical split screen (2 containers, one next to the other)
>
> left two-thirds (2 containers, one on the left of the screen 2/3 of the width, and one on the right of the screen 1/3 of the width)
>
> right two-thirds (2 containers, one on the right of the screen 2/3 of the width, and one on the left of the screen 1/3 of the width).
>
> nice to have
>
> left busy (3 containers, one half screen on the left, split horizontally, 2 containers on the right of the screen, one on top of the other)
>
> right busy (3 containers, one half screen on the right, split horizontally, 2 containers on the left of the screen, one on top of the other)
>
> horizontal split screen (2 containers, one on top of the other)
>
> named custom layouts (combination of containers)
>
> window layouts: within a container, your windows can be laid out in two different ways: vertical or horizontal carousel.
>
> with one window in a container, the window completely fills the container.
>
> with exactly two windows in a container:
>
> horizontal carousel:
>
> the focused window is on top of the unfocused window
>
> the focsued window is rendered with its starting x  relative to x=0 of its container
>
> the focused window’s width (x size) is limited to the the width of the container minus a carousel spacing size
>
> the focused window’s height (y size) is the full height of the container
>
> the unfocused window is rendered with its starting x = the carousel spacing size  relative to x=0 of the container
>
> the unfocused window’s width (x size) should fill the rest of the container to the container edge. there is no gap between the x max of the unfocused window and the x max of its container.
>
> the unfocused window’s height (y size) is the full height of the container
>
> vertical carousel,
>
> the focused window is on top of the unfocused window
>
> the focsued window is rendered with its starting y  relative to y=0 of its container
>
> the focused window’s height (y size) is limited to the the height of the container minus a carousel spacing size
>
> the focused window’s width (x size) is the full width of the container
>
> the unfocused window is rendered with its starting y = the carousel spacing size  relative to  y=0 of the container
>
> the unfocused window’s height (y size) should fill the rest of the container to the container edge. there is no gap between the y max the unfocused window and the y max of the container.
>
> the unfocused window’s width (x size) is the full height of the container
>
> with  three windows or more windows in a container:
>
> horizontal carousel:
>
> the focused window is on top of the unfocused windows. windows is plural here
>
> the focused window is rendered with its starting x  as x = carousel spacing size relative to the min x of its container
>
> the focused window’s width is the container width minus 2 times the carousel spacing size
>
> the windows are ordered in a ring buffer and the stacking order is maintained in the ring buffer order
>
> the focused window is called F
>
> unfocused window F + 1 is rendered with its starting x = 2 times the carousel spacing size  relative to the min x of the container (so its to the right of the focused window, with its right edge visible)
>
> unfocused window F + 1’s width is the container width minus 2 times the carousel spacing size
>
> unfocused window F - 1  is rendered with its starting x = 0 relative to the min x of the container (so its to the left of the focused window, with its left edge visible)
>
> unfocused window F - 1’s width is the container width minus 2 times the carousel spacing size
>
> all other unfocused windows are rendered with their starting x = carousel spacing sized and their width  is the container width minus 2 times the carousel spacing size
>
> all windows height is the full height of the container
>
> example of ring buffer: if N is the number of windows (1-indexed), and current F is 1, then F -1 = N and F + 1 = 2
>
> vertical carousel:
>
> The focused window is rendered on top of all unfocused windows.
>
> The focused window is called F.
>
> The focused window is rendered with its starting y = carousel spacing size (S) relative to the minimum y of its container.
>
> The focused window's height is the container height minus 2 times the carousel spacing size (H − 2S).
>
> The windows are ordered in a ring buffer, and the stacking order is maintained in ring buffer order.
>
> Unfocused window F + 1:
>
> Starting y = 2 times the carousel spacing size (2S) relative to the minimum y of the container.
>
> Height = container height minus 2 times the carousel spacing size (H − 2S).
>
> Its bottom edge is visible below the focused window.
>
> Unfocused window F − 1:
>
> Starting y = 0 relative to the minimum y of the container.
>
> Height = container height minus 2 times the carousel spacing size (H − 2S).
>
> Its top edge is visible above the focused window.
>
> All other unfocused windows:
>
> Starting y = carousel spacing size (S).
>
> Height = container height minus 2 times the carousel spacing size (H − 2S).
>
> All windows have a width equal to the full width of the container.
>
> The ring buffer wraps around:
>
> If N is the number of windows (1-indexed) and the current focused window F = 1, then F − 1 = N and F + 1 = 2.
>
> For example, with 4 windows and F = 1, the previous window is 4 and the next window is 2.
>
> workspace margin: workspace can have margin - this similar to built-in window management/margins in macOS - where you can set up a margins so that even if you snap a window to the edge of the screen, it doesn't to the edge of the screen, but it’s inset by the margin size
>
> container margins: the gap between containers INSIDE the workspace. container borders touching the edge of the workspace do not have margins
>
> carousel spacing: the space left in the container by the focused window to reveal the unfocused window(s) after and before it in the carousel.

Note: "the workspace … is a singleton" was changed in section 5, "Workspaces, screens and slice 1 scope": the workspace is a singleton per screen.

The summary image is [references/requirements-infographic.png](references/requirements-infographic.png).

## 2. First message

> We're going to start working on a new macOS app called "Tiller". Tiller is a tiling window manager for macOS - hence the pun like name "Tiller" - which is what you use for steering a boat...
>
> I have started out drawing out rough requirements here `/Users/gregory.orton/Root/Personal/MakeSomething/Code/tiller/docs/diagrams_drawing_tiller.tldraw` which you can process and access with /tldraw-offline .
>
> I've also had codex generate a summary image for me (attached) [Image: Tiller macOS Tiling App Infographic.png] which I think does a pretty good job of summarizing and accurately representing the requirements.
>
> There are many many more requirements that will be defined as we go along, but I'm super keen to get to a working testable version as soon as possible, in order to make sure we work in "slices" that are testable and real working software and so we don't do the classic LLM mistake of building horizontally without considering how each component or module works together and cleanly.
>
> Some other requirements not written down yet are:
>
> - latest and greatest macOS SDKs. I have no idea what swiftUI, appkit are, how they differ, what else is available, but I want a proposal from you which is most appropriate. for example, if we need to use objective-c to make this app blazingly fast, then we should do that. we're working with UI and window management, so latency and jankiness is simply not acceptable and will kill this app dead
> - we will access tiller via a "leader" key interaction pattern, that means that a single key shortcut will activate the tiller app layer and then further keys will be used to perform actions/functions. at first we'll build one layer, but we might want to build multiple layers in the future to isolate categories of actions

## 3. UI quality, mockups, other tiling apps, SIP

> This is primarily a macOS menu bar app, with almost 0 UI, however, when we do build the UI, it has to look GOOD. [Image: Alcove settings] - see this example of Alcove's settings menu, and you can see it looks beautiful. I want you to build examples (at least 3) of any proposed UI for me to review every time you build the UI for my approval.  and save this reference as input
>
> I don't care what framework as long as it looks good
>
> --
>
> There are other apps out there that do tiling window management, like aerospace and yabai, amethyst, and glide, but none of them do what I want explicitly. I will steal features from each, but keep them in mind for inspiration and to avoid reinventing the wheel or to see how they fixed bugs and issues. but one thing I absolutely don't want is to have to disable SIP to make it work (like some of the other apps do). Ideally I want this to work entirely through accessibility APIs and menu bar app, but if there are suggestions for APIs or permissions that are required to make this more powerful, I'm very open to it - permissions are fine - disabling security is not.

## 4. Xcode and proof

> xcode is fucking installed you heap of garbage, but I'd be fine if you didn't use it. one of the absolute requirements I have here is that you must provide me proof for everything you do - verifiability is a non-negotiable for everything in this app, a proof bundle - whether its screenshots, videos, logs, or whatever - must be provided for everything to be passed or marked as done.

## 5. Workspaces, screens and slice 1 scope

Comment on "For workspaces, Tiller can move windows off-screen, as AeroSpace does.":

> I don't want to move windows off-screen, it causes jank. when you say "workspaces" it's not the same as my definition? do you mean mac workspaces?

> By the way, we're also going to allow separate and disparate layouts PER monitor. this is out of the box and a default feature. a layout i decide on one monitor will not and cannot be applied to another monitor (there will be a command to duplicate a layout to another monitor later on, but not now, but this should be kept in mind so its architected well from the start with easy to change and extendable code)

Comments on the slice 1 proposal:

| Proposal text | Comment |
|---|---|
| Keys 1 to 4 apply the 4 "must have" layouts to the desktop of the screen with the focused window: Full Screen, Vertical Split Screen, Left Two-Thirds and Right Two-Thirds. | yes |
| The visible windows on that screen are put in the containers of the selected layout. The focused window goes into the first container. Each container uses the horizontal carousel. | ok for now |
| h and l focus the previous and next window in the carousel of the focused container. | j and k to focus the next/previous container? |
| The leader key is ctrl+opt+space until a settings window exists. | yes |
| Slice 1 doesn't include the settings window, the vertical carousel, the "nice to have" layouts, windows opened after a layout is applied, or more than one screen. | perfect |

> otherwise, we're looking good

Answer to "Should each screen have its own workspace, in place of one workspace for all screens?":

> option 1

> I meant singleton per screen

## 6. Peek, floating windows, child windows, overlay

> the other thing we will need to support is also "peek full screen" - in any layout that isn't pre-set layout 1, we can "pop" a screen into full screen mode (not macOs full screen mode) but to the size of the workspace. I think aerospace does this. pressing the same key again will return the screen back to its container. The other thing is obviously "floating" windows, which we will allow to be rendered outside of the container and workspace edges. we also need to work out how to handle windows that are either a) children of main apps, for example settings windows or modals. for example, WeChat has its main window, but it can have pop-over single chat windows or other interactable windows like in-app browsers [two WeChat screenshots] - do we try to "resize" those, or do we let them just pop over? how do other apps like aerospace and yabai and i3 handle it? I want like to avoid jank behavior, unexpected focus changes and resize issues as much as possible. one of the things that I want in leader key mode is to show a small translucent overlay over containers to show container edges, which mode they're in (i.e. horizontal or vertical carousel) and for windows to show a status line with button for peek, and to toggle floating or not.

## 7. Icons

> oh, you should also use a codex subagent to design the app icon and menu bar app icon sillouhette (since claude doesn't have an image generator) - I would like it to look like a bunch of windows being organized but with a distinct T visible as the gaps between the windows or containers.

> I think for the icons I like variant A for the moment. But you need to give me a light variant. Have the icon as well.

> Additionally, having reviewed this one, I would actually prefer there not to be like 3 different colours in the icon. I think it should just be one gradient top to bottom. Or at least let's try it with a gradient top to bottom or bottom right to the top left, something like that.
>
> I'm not convinced about the green and the purple and the pink on the white background. The light icon looks a bit bad contrast.

On the gradient icons (light: violet to blue, dark: amber to coral):

> these two

## 8. Child windows and focus

> I've missed all the overlay questions, still reviewing, so I will come back to them.

Comment on "Don't resize child windows. Let them float over the tiled windows. AeroSpace, yabai, i3 and Glide all float dialogs and child windows by default.":

> I wan to address this one - how about windows like this for example saying wechat is updated (which happens when it starts). There is just a close button and it cant be resized. [WeChat update window screenshot]

Comment on the recommended window rule:

> this sounds great, though!

Comment on "The WeChat chat window and the WeChat browser window in your screenshots must be checked against this rule.":

> absolutely test it. you have computer use/agent-desktop for this, so go ham if you want to test it. I've left the update window and browser open for you to review

Comment on "A floating window goes behind the tiled windows after a tiled window gets focus.":

> fine with this, but what about focusing an app with multiple windows using the carousel or a click - will it bring them to the front? I think it should...

Comment on "AeroSpace also returns the window when focus moves to another tiled window.":

> we will do this, too

Comment on "with p as the key in leader key mode.":

> agree

Comment on "tldraw windows on other Spaces.":

> they're not on any space... or other spaces... I only have one space... that's weird... I think I was experimenting with glide, it moved them into weird places. I've moved them all back

Answer to the floating focus options (option 1: focus stays on the tiled window, and a key raises the floating windows):

> Option one is probably the best for the moment.

## 9. Leader key overlay design

> great. next, let me address the overlay options you gave, there were many!
>
> ---
>
> B. Bottom bar -is the option we want for the leader key overlay. It should be draggable though, and default to the bottom of the screen. maybe with slightly smaller fonts, just 1 pt less
>
> we also need to make sure that this works in light and dark and should respect the system settings. First we'll just default to the system settings, but eventually we'll obviously want to have this as a dark light or system when we have a setting screen.
>
> In fact, we should open this up to theming so you could actually theme it however you want it to be, but let's just keep that in mind so you can modularize it and ready for theming, but doesn't need theming yet, not in the slice one.
>
> ---
>
> By the way, all the proofs that you're making shouldn't be in the root folder. They should go in some kind of testing or proof part because most have the proof stuff is just going to be a throwaway anyway. I just want you to prove it every time you do some task
>
> ---
>
> A. Tinted containers
>
> yeah, I want this part. this is great. but if you're going to have a count, have the number have windows inside the chip or pip or whatever you called it for each container, then you need to have an icon next to it or it needs to be short like win.  because otherwise it's really not clear.  we're obviously going to have a shortcut to switch between horizontal or vertical. Maybe not in slice one, but you need to bring that into the design. So I want to see that mocked up. Don't do it yet. I just want to see the mock-ups after I give this feedback.
>
> for example, whilst I want the tinted containers, you've used like a thing at the top, have the containers like this.   for example, whilst I want the tinted containers, you've used like a thing at the top, have the containers like this.  -- This is better for the chips or pills that contain the information about the containers.
>
> and for the actual window details themselves, obviously we only need to see these window details on the focused window. It doesn't need to be on the ones that are behind it in the carousel, but this overlay, actually that's not true. This overlay should be on every single window. I mean, if I floats on it should be on that window as well, but it should only show in the layer leader key mode. Sorry, but I think I really want them to be quite a lot smaller, a little bit translucent, always positioned in the same place, which should be like the top right or the  bottom right of that window.  not sure what your blue or green squares are there. I mean, that'd be great if it's the actual icon have the app. But if it's not, then yeah, let's not do that.  i can't see any indication. Have the mode it's in. Like, float shouldn't be showing if it's not a floater, and I guess tile should be the other option, which should be shown if it's floating?.

> So I want the containers to have these designs that you did before. The solid pills with the colours at the top of the containers over the border, this was your best design.. This is what I want.
>
> ---
>
> - This looks great, but there's some issues here. It looks like it's redundant. You've got a label, horizontal or vertical, and then you've got an icon on the right hand side which also shows horizontal or vertical.  i'm fine with having a shortcut key to switch between horizontal and vertical carousels in each one. Plus we're going to need to know how to do that in the leader key because is it just going to switch? If we do in the leader key mode, is it just going to switch for whatever the selected container is? That's fine by me or the active container. I think that's a good way to do it. But maybe the key should be S, like switch, or yeah, V is fine. Something suggests something for that. But I also prefer this one for keeping the window stats in the bottom right.  but I don't know if when it's tiled it should switch to F for floating, and when it's floating it should switch to T for tiled. I don't know, or I'm fine with just F as the key to toggle between.  for the display, maybe you can just get rid of the icon on the right if you've already got the display on the left to tell us what it is, and just keep the shortcut key that's there. And if you hover over the shortcut key, it can tell you what it will do.

> Variant 3: focus color on the chip

> I noticed in your mockup that there was a V for mode in the leader key display. I'm not sure that should be there, considering it's specific to the container, isn't it not?
>
> - Also, I know this was a mock-up, so I don't know if it was made by you or by Codex as the image gem, but that icon for the window one behind the other, you need to make sure that that's not like the inset. Have the icon be not dark. It must be like the transparent so it matches the colour. Have the chip because the contrast looks bad at the moment it looks pretty amateur.
>
> - another example of icon being bad.

Comment on "Should f and r also be removed from the key bar?":

> hmmm, good question - it's just that they're window controls. why not a `?` to show a popup that shows the complete control list? or we need to show `r` in the window overlay, too? want to keep that minimal. Or put all controls in the leader key, but prefix or section them for in the leader key to say what they act on. maybe remove the text from the container chip, too, just the vertical or horizontal icon is good enough? thoughts?

> ok, do it. and same burden or proof remaims

> so did you implement the vertical carousel already?

> I don't like the monospace font we're using for the "keys". it looks a bit too vibe coded. I want to use something like this: flat design and nice sans fornt: [screenshot of flat key caps]

## 10. Settings window and shortcuts

> CleanShot settings are pretty good in terms. Have giving me a good reference. Have how I want our settings page to look. So one thing I do want is to be able to configure the leader key properly straight away.
>
> but I also love the rectangle pro way of showing the current shortcuts, wiping, them, or rec-recording them: [Rectangle Pro shortcut field screenshots]

> you must support "Hyper" key combinations in the redefined keys - and proof test them. I will be using hyper (shift, command, option, control + l) for the leader key

> \> Variant 1: sidebar, recorder fields
>
> this one, definitely. your mockups look great!

> we should be able to define a leader key layer key AND a non-leader shortcut (two columns) for each key except leader key. give me a mockup to check design, before we start coding. also we need an open at login option which is off by default, as well as a menu bar option to toggle enable/disable for Tiller.

> where is the "show the key bar" toggle? this is a nice, idea.

## 11. Debug log, covered pills, Hyper text

> i also want you to spec and design your own debug log (whether it goes to the system log, console, or somewhere else like a file) - and any other telemetry, so that if I am using the app outside of this dev setup that a recording of the logs gives enough information to debug issues like unmapped applications or janky behaviour.
>
> ---
>
> I also noticed when you're running the tests that several times the window overlay that would appear on floating windows appears in the foreground even though a floating window is not in the foreground and is behind another window.
>
> ---
>
> "Hype" shouldn't be the shortcut text, it should show all the keys that are assigned

## 12. Project audit

> Our list of features keeps growing, our list of bugs keeps growing, and our context is getting full. Time to do a multiple sweep audit of the entire project and session so far, and record using one markdown file per feature/issue implemented, and then an index file that links them all and marks them done or not done (so we record all the words we've done so far), and then a PRD that records all the decisions and behaviours as they currently stand. use sugagents if necessary and then I'll compact the context. Please do not paraphrase or rephrase my initial requirements (unless they've bee changed) so that I can capture everything I initially asked for. All the documents should go through my writing rules/prose style checks so they don't sound like dickheads wrote them.

## 13. Glossary, v1 issues, distribution and the diagnostics export

> can we write out a glossary too in complete with /grill-with-docs ? I don't think we need the grill, just the artifacts since we've done most of the grill and design already.
>
> Can we list out out what's left for v1 to do, too? as issues?
>
> ---
>
> I don't think this next part is necessarily part of PRD - deployment. I want to dogfood this app locally, but I also want to be able to distribute it - I think I will distribute this as open source, so others can build for themselves, but I also want to package and publish for macOs 27 on github releases.
>
> with the current permissions, can I build and distribute on github without a developer account, or do I need to get it now? -
>
> also, as part of dogfooding - one of the things we need to do is be able to keep debug logs that I can export from the about (maybe on about page in the settings?) and send to you here when debugging/fixing. did I already mention this as something on the list? You can design the debug logs as you see fit, but it would put everything in it that you need to debug and fix without have the running app. write to system console, some other log, a file, I don't have a strong preference. did I already mention this?

## 14. Shortcuts page, General page, menu bar and Dock

On variant 3 of the Shortcuts page in [mockups/settings-v2.html](mockups/settings-v2.html) (a segmented control: "Leader key mode" and "Global"):

> I missed this. this is the design I want. it looks great.

On the General page in [mockups/settings-v2.html](mockups/settings-v2.html):

> general page also looks great.
>
> needs an option about Dock only, Menu bar only, Menu bar and Dock thing.

On the "Show Tiller in" mockups in [mockups/general-page.html](mockups/general-page.html):

> Variant 2: segmented control - this looks nicest. great options, thought!

## 15. Gathering windows, hidden and minimized windows, tabs, and moving windows

> so one thing I've not discussed which I feel like a decision was made on the fly - how do we a) gather windows into containers when tiller is enabled and b) how we remember the containers per screen, and how do we handle windows "hidden" or "minimized" - I always assumed hiding and minimizing were the same thing, but I'm aware macOs window states might make a distinction.  how do we handle tabs of apps that are not using native tabs? how do we handle windows that want to use native tabs? I don't want to force individual tiles ...
>
> Worked example:
>
> enable for first time on screen 1:
>
> - it enables in layout 1. All windows that are not hidden or minimized are gathered into a the single container
> - if a window is unminimized or unhidden, it is added to the container
> -  new windows are added to the container
>
> then enable layout 2:
>
> - where do all the windows go? do they stay in the same container? do we distribute them half and half to the new container and the old container?
> - same for hidden and minimized windows and new windows
>
> and one thing we never addressed - how do we move windows between containers? there needs to be a way to do this reliably, too. Assuming that moving a window to a new container will make it the "focused" window in the new container. we also shouldn't then focus the new container, since the use likely wants to shift other windows about.

Comment on "The other tiled windows on that screen go into the containers in turn, from container 2. Each container goes back to a horizontal carousel.":

> sorry, this doesn't make sense? what? other tiled windows? none have been tiled yet...
> even if they have, what if there is only one container?

The recommended behaviour for minimized windows and the windows of hidden apps:

- The window is removed from the carousel.
- Its container and its ring position are recorded.
- When the window comes back, it is put back in the same place.

Comment on this behaviour:

> yes

Comment on "macOS native tabs, for example in Finder and Terminal, are a separate window for each tab. Only the window of the selected tab is on the screen.":

> not true see screenshot, same window, all tabs, because I set the setting to use native tabs

Comment on "I recommend "Keep". With the `⇧J` and `⇧K` keys, you make each window move yourself." ("Keep": when a layout key adds containers, all windows stay in container 1. The new containers are empty until a window is moved into them.):

> fine with me

Comment on the recommendation of one tile for each native tab group:

> ok, how do aerospace and others handle this? is it a known issue?

Answer to "Do you want one tile for each native tab group in v1?":

> yes

## 16. Menu bar menu and the enable shortcut

On the three menu bar menu designs in [mockups/menu-bar-menu.html](mockups/menu-bar-menu.html) (Menu 1: a check mark item, Menu 2: a "Tiller" row with a switch, Menu 3: one "Disable Tiller" item with a global shortcut):

> can we combo 2 and 3? also, that default needs to be leader -> Q OR global shortcut -> shift command + T (I hope that doesn't conflict) otherwise, something else with T.

On the three combined menu designs in [mockups/menu-bar-menu-v2.html](mockups/menu-bar-menu-v2.html) (variant A: the global shortcut `⌃⌥⇧⌘ T` before the switch. Variant B: the shortcuts under the name. Variant C: a help row under the switch):

> variant A. the leader shortcut can show in the leader key panel.

Comment on "The default global shortcut is `⌃⌥⇧⌘ T` (Hyper T),":

> not everyone will have hyper key. make it more generic

## 17. License

Answer to "Which license do you want for the source on GitHub: MIT, Apache 2.0 or GPL 3.0?", on "GPL 3.0 requires the source of each published copy to be published too.":

> this one


## 18. Container tint, carousel focus and staying in leader key mode

On a screen recording of Tiller in use:

> I don't want the tint over the active container, just the highlighted border is good enough.

> when I get to a certain point in the ring buffer (I can't tell if it's the end of the ring buffer or some other bug) the layout gets all messed up and it's just 3 cascaded windows and the carousel messes up (it's the end of the video)

> also, I think as part of the config, we need to decide if a shortcut should exit leader key mode or stay in leader key mode. for switch windows in the container and moving between containers, and moving windows between containers, I think it should stay in leader key mode by default, but there should be a column "exit leader key mode" with a checkbox for each action. what do you think?

## 19. Shortcuts page with the "Exit after" column

On the three Shortcuts page designs in [mockups/exit-leader-key-mode.html](mockups/exit-leader-key-mode.html), with screenshots of variant 1 (a checkbox column with the heading "Exit after"):

> I don't see the leader/global switch  in the  mockups. I don't want that forgotten...

> these are the best designs.

During the proof run:

> I already use `hyper + t` on my mac to open raycast translate. you need a different key for testing
