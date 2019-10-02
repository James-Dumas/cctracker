# cctracker

cctracker is a music tracker program written for the CC: Tweaked mod for Minecraft.

You can easily download it on your computercraft computer with this command:

`pastebin get 290rwTEd cctracker`

## Manual
Songs are made up of frames, and frames are made up of rows and channels.
There are seven channels, and each channel can play one note at a time.
One row represents the smallest time interval of the song.
The speed value is the number of game ticks (1/20 second) between each row.

Frames are arranged on the frames panel, to the bottom right.
The white number on the left is the index. the green/yellow number on the left is which frame exists at that index.

The editor panel is the large panel in the center.
Notes are displayed on it like this:

```
|C#3F7|
 ^ ^^^
 | |||
 | ||volume
 | |instrument
 | octave
 note
```

Instrument and note values are displayed as hexadecimal digits: [0123456789ABCDEF]

The instrument values correspond the the 16 note block instruments in the latest version of the game.

### Controls

#### global
* shift + arrow keys - switch panel
#### top panel
* arrow keys - choose option
* enter/space - select option
#### editor panel
* arrow keys - move cursor
* shift + space - play from first frame
* shift + S - enter selection mode
  * (selection mode):
  * arrow keys - move cursor
  * shift + S - leave selection mode
  * C - copy selection to clipboard
  * X - cut selection to clipboard
  * Z - select entire channel
  * A - select entire frame
* shift + V - paste clipboard at cursor
* shift + M - mute/unmute current channel
* shift + [0123456789ABCDEF] - select instrument
* various keyboard keys - enter note / instrument / volume
  * A key is the lowest F#, Z key is G, S key is G#, X key is A, etc.
#### frames panel
* up/down - change frame index
* left/right - change frame at current index
