# cctracker

cctracker is a music tracker program written for the CC: Tweaked mod for Minecraft.

![cctracker_example](https://github.com/James-Dumas/cctracker/blob/master/cctracker.png)

You can easily download it on your ComputerCraft computer with this command:

`wget https://raw.githubusercontent.com/James-Dumas/cctracker/master/cctracker.lua cctracker`

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

The effects bar is the column to the left of the editor. When an effect is placed it will be applied when the notes on that row are played during playback. For effects that require a value, you can type in hexadecimal digits next to the symbol.

### Controls

#### global
* shift + arrow keys - switch panel
#### top panel
* arrow keys - choose option
* enter/space - select option
#### editor panel
* arrow keys - move cursor
* space - play from current frame
* shift + space - play from first frame
* shift + S - enter selection mode
  * (In selection mode):
  * arrow keys - move cursor
  * shift + S - leave selection mode
  * delete/backspace - delete selection
  * C - copy selection to clipboard
  * X - cut selection to clipboard
  * Z - select entire channel
  * A - select entire frame
  * R - replace instrument with current instrument
  * equals/minus - transpose selection up/down half step
  * right/left bracket - transpose selection up/down octave
* shift + V - paste clipboard at cursor
* shift + M - mute/unmute current channel
* shift + [0123456789ABCDEF] - select instrument
* various keyboard keys - enter note / instrument / volume
  * the 'A' key is the lowest F#, 'Z' key is G, 'S' key is G#, 'X' key is A, etc.
  * the next octave starts on the '1' key on F#, continuing the same pattern. (piano keys)
  * for instrument and volume just press one of [0123456789ABCDEF]
* backspace - delete note
* delete - delete note and move down a row
#### frames panel
* up/down - change frame index
* left/right - change frame at current index
* I - insert new frame before current frame
* delete - delete current frame
#### effects bar
* n - skip to next frame
* s - stop song
* t - change speed
  * value is the speed to set to in hexadecimal
  * set to 00 to reset to the song's default speed
* j - jump to frame
 * value is the index of the frame to jump to in hexadecimal
