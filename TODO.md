URL
`http://cgss.cf/static/list.json`
`http://cgss.cf/static/pattern2/abs9_masterplus.json`

List.json format
```JSON
{
	SongID : {
	  title : "Japanese Name",
	  type : cu | co | pa | all,
	  bpm : [lowBPM,highBPM],
	  
	  DiffID : [star876,stacost,isAvail]
	}
}
```

```
	lowBPM : number
	highBPM: number
	
	star876: digits
	stacost: digits
	isAvail: boolean
	
	SongID : [a-z0-9_]+
	DiffID : debut | regular | pro | master[plus]{0,1}
	boolean: true | false
	number : digits + [decPt + digits]{0,1}
	digits : digit  + digits*
	digit  : [0-9]
	decPt  : [.]
```

Pattern.json format
```JSON
{
	bpc  : number,
	style: type,
	beat : ["beat in a bar",...],
	total: noteCount,
	notes: [tuple(timing,noteIndex),...],
	long : [tuple(timing,timing,noteIndex,slideDir),...],
	slide: [pair(
	  tuple(timing,noteIndex,slideDir), # Start
	  tuple(timing,noteIndex,slideDir)  # End
	),...],
}
```

```
  number   : digits + [decimalPt + digits]{0,1}
  BiaB     : digits
  noteCount: digits
  
  timing   : number
  digits   : digit + digits*
  
  digit    : [0-9]
  noteIndex: [1-5]
  decimalPt: .
  slideDir : "" | [LR]
```

RevisedList.json format
- add transliterated


RevisedPattern.json format
- fix mistakes
