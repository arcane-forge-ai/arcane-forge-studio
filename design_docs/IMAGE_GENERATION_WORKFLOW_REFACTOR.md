# Image Generation Workflow Refactor

## Summary of changes

- We are refactoring our process of image generation. Previously user basically directly call A1111 with `model+lora(s)+config+prompt(s)`. This is way too hard for user to use since they are not AI artists and have limited knowledge in Stable Diffusion. Therefore we now change to a process of:
  - user picks a workflow, either with AI assist or from our workflow gallery
  - user provide workflow inputs (prompts)
  - user execute the workflow
- We will still keep the current Generation screen as a more "Expert Approach". We haven't decided how to show it on the menu yet. So let's just keep the file (maybe with a rename).
- Some components from the current image generation screen may be re-used in our new screens. If a component can be re-used, make sure we extract it out into a proper place so screens don't need to do cross referencing.

## High-Level Flow

```
`Generation` in Menu / Asset Detail > `Generate Image` Button
   ↓
Screen 1: Target Asset + How to Start
   ↓
Screen 2: (Chat)   OR   Screen 4B (Workflow Browser)
   ↓
Screen 3: Unified Generation Screen
   ↓
Results (inside Screen 3)
```

## Screen-by-Screen ASCII Mockups

### Screen 1 - Select Target + How to Start

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ✨ Image Generation                                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│ Target Asset                                    [+ New Asset]                 │
│ ┌────────────────────────────────────────────┐                               │
│ │ Select an asset ▼                           │                               │
│ └────────────────────────────────────────────┘                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ How would you like to start?                                                  │
│                                                                              │
│ ┌───────────────────────────────┐   ┌───────────────────────────────┐      │
│ │ 🗨️ Describe in Chat            │   │ 🧩 Browse Workflow Library     │      │
│ │                                │   │                                │      │
│ │ Tell the AI what you want.     │   │ Pick a predefined workflow     │      │
│ │ We’ll infer the workflow.      │   │ (icons, sprites, UI, etc.)     │      │
│ │                                │   │                                │      │
│ │        [ Use Chat ]             │   │     [ Browse Workflows ]       │      │
│ └───────────────────────────────┘   └───────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────────┘
```

Notes:

* The "header" part of selecting asset can just re-use what we have in current image generation screen.
* If user comes to this screen from asset detail dialog, then the asset should be pre-selected.
* Before selecting an asset, the bottom half should be grayed/50% opacity and shouldn't be active (but still visible)

### Screen 2a - Chat (AI INFERS WORKFLOW)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ✨ Image Generation                                                           │
│ Target Asset: Max Health Up        (i) Asset Info                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Describe what you want                                                       │
│                                                                              │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ A green shield icon that increases max HP,                                 │ │
│ │ fantasy style, fits roguelike UI                                           │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│                                                                              │
│                                                                              │
│ [ ← Back ]                                               [ Continue → ]      │
└──────────────────────────────────────────────────────────────────────────────┘
```

Notes:

* Again you can reuse the header. The header remains unchange through out the entire generation flow
* Behavior:
  * On `Continue`:
    * Call a backend endpoint `/api/v1/workflows/recommend` and ask for 3 recommendations
    * Will receive up to 3 workflow(s).
  * Then navigates to Screen 2b

### Screen 2b -- Workflow Browser

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ✨ Image Generation                                                           │
│ Target Asset: Max Health Up        (i) Asset Info                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Choose a workflow                                                            │
│                                                                              │
│ ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                    │
│ │ Name          │  │ Pixel Sprite  │  │ UI Button     │                    │
│ │ Description   │  │ 16×16 / 32×32 │  │ Flat / Clean  │                    │
│ │ Sample Image  │  │               │  │               │                    │
│ │ [TAG1] [TAG2] │  │ [ TAG ]       │  │ [ TAG ]       │                    │
│ └───────────────┘  └───────────────┘  └───────────────┘                    │
│                                                                              │
│ [ ← Back ]                                               [ Continue → ]      │
└──────────────────────────────────────────────────────────────────────────────┘
```

Notes:

* Again header should be the same as before
* If navigated from 2a, then it should just show the workflows recommended. Likely no need to make another API call
* If navigated from 1, then it should call "List workflows" endpoint and show all the workflows.
* Selecting a workflow enables **Continue**
* Should have a visbile effect to distinguish selected vs non-selected (same as favorite generation vs non-favorite generation in any asset detail screen)
* Continue → **Screen 6**
* Workflow is now **locked for this generation**


### Screen 3 - Generation Screen

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ✨ Image Generation                                                          │
│ Asset: Max Health Up     (i) Asset Info                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│ ┌───────────────┬───────────────────────────┬─────────────────────────────┐ │
│ │ Asset Info    │ Prompt                    │ Recent Generations           │ │
│ │ ──────────────│                           │                             │ │
│ │ Name:         │ Positive Prompt           │ ┌───────────┐              │ │
│ │ Max Health Up │ ┌───────────────────────┐ │ │ Image A   │              │ │
│ │────────────── │ │ A green shield icon... │ │ └───────────┘              │ │
│ │ Workflow:     │ └───────────────────────┘ │ ┌───────────┐              │ │
│ │ Game Icon     │                           │ │ Image B ★ │              │ │
│ │ DESCRIPTION   │ Negative Prompt           │ └───────────┘              │ │
│ │ [CHANGE]      │ ┌───────────────────────┐ │ ┌───────────┐              │ │
│ │               │ │ text, watermark        │ │ │ Image C   │              │ │
│ │               │ └───────────────────────┘ │ └───────────┘              │ │
│ │               │                           │                             │ │
│ │               │ [ ✨ Generate Prompt AI ] │                             │ │
│ │               │                           │                             │ │
│ │               │ ▸ Advanced               │                             │ │
│ │               │                           │                             │ │
│ │               │ [ Generate ]              │                             │ │
│ └───────────────┴───────────────────────────┴─────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

Notes:

* Again header should be the same as before
* 3 column:
  * first one has
    * asset info (name, description, etc.) grouped in a container
      * If user provided a description in screen 2, it should also show up here
    * workflow card
      * Just reuse the one in Screen 2b -- we will see if it fits
  * 2nd column should be very similar to what we have now in current image_generation_screen
    * prompts
    * ai prompt helper
    * size
    * batch
    * generate button
  * 3rd column still do recent generations, just like what we have now
* Generate will invoke `POST /api/v1/workflows/{workflow_id}/execute` endpoint. 
