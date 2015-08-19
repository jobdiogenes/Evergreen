var physical_characteristics  = {
	c : {
		label     : "Electronic Resource",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	a : "Tape Cartridge",
						b : "Chip cartridge",
						c : "Computer optical disk cartridge",
						f : "Tape cassette",
						h : "Tape reel",
						j : "Magnetic disk",
						m : "Magneto-optical disk",
						o : "Optical disk",
						r : "Remote",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	a : "One color",
						b : "Black-and-white",
						c : "Multicolored",
						g : "Gray scale",
						m : "Mixed",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Dimensions",
				values: {	a : "3 1/2 in.",
						e : "12 in.",
						g : "4 3/4 in. or 12 cm.",
						i : "1 1/8 x 2 3/8 in.",
						j : "3 7/8 x 2 1/2 in.",
						n : "Not applicable",
						o : "5 1/4 in.",
						u : "Unknown",
						v : "8 in.",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Sound",
				values: {	' ' : "No sound (Silent)",
						a   : "Sound",
						u   : "Unknown",
				},
			},
			g : {	start : 6,
				len   : 3,
				label : "Image bit depth",
				values: {	mmm   : "Multiple",
						nnn   : "Not applicable",
						'---' : "Unknown",
				},
			},
			h : {	start : 9,
				len   : 1,
				label : "File formats",
				values: {	a : "One file format",
						m : "Multiple file formats",
						u : "Unknown",
				},
			},
			i : {	start : 10,
				len   : 1,
				label : "Quality assurance target(s)",
				values: {	a : "Absent",
						n : "Not applicable",
						p : "Present",
						u : "Unknown",
				},
			},
			j : {	start : 11,
				len   : 1,
				label : "Antecedent/Source",
				values: {	a : "File reproduced from original",
						b : "File reproduced from microform",
						c : "File reproduced from electronic resource",
						d : "File reproduced from an intermediate (not microform)",
						m : "Mixed",
						n : "Not applicable",
						u : "Unknown",
				},
			},
			k : {	start : 12,
				len   : 1,
				label : "Level of compression",
				values: {	a : "Uncompressed",
						b : "Lossless",
						d : "Lossy",
						m : "Mixed",
						u : "Unknown",
				},
			},
			l : {	start : 13,
				len   : 1,
				label : "Reformatting quality",
				values: {	a : "Access",
						n : "Not applicable",
						p : "Preservation",
						r : "Replacement",
						u : "Unknown",
				},
			},
		},
	},
	d : {
		label     : "Globe",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	a : "Celestial globe",
						b : "Planetary or lunar globe",
						c : "Terrestrial globe",
						e : "Earth moon globe",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	a : "One color",
						c : "Multicolored",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Physical medium",
				values: {	a : "Paper",
						b : "Wood",
						c : "Stone",
						d : "Metal",
						e : "Synthetics",
						f : "Skins",
						g : "Textile",
						p : "Plaster",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Type of reproduction",
				values: {	f : "Facsimile",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	a : {
		label     : "Map",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	d : "Atlas",
						g : "Diagram",
						j : "Map",
						k : "Profile",
						q : "Model",
						r : "Remote-sensing image",
						s : "Section",
						u : "Unspecified",
						y : "View",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	a : "One color",
						c : "Multicolored",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Physical medium",
				values: {	a : "Paper",
						b : "Wood",
						c : "Stone",
						d : "Metal",
						e : "Synthetics",
						f : "Skins",
						g : "Textile",
						p : "Plaster",
						q : "Flexible base photographic medium, positive",
						r : "Flexible base photographic medium, negative",
						s : "Non-flexible base photographic medium, positive",
						t : "Non-flexible base photographic medium, negative",
						u : "Unknown",
						y : "Other photographic medium",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Type of reproduction",
				values: {	f : "Facsimile",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Production/reproduction details",
				values: {	a : "Photocopy, blueline print",
						b : "Photocopy",
						c : "Pre-production",
						d : "Film",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Positive/negative",
				values: {	a : "Positive",
						b : "Negative",
						m : "Mixed",
						n : "Not applicable",
				},
			},
		},
	},
	h : {
		label     : "Microform",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	a : "Aperture card",
						b : "Microfilm cartridge",
						c : "Microfilm cassette",
						d : "Microfilm reel",
						e : "Microfiche",
						f : "Microfiche cassette",
						g : "Microopaque",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Positive/negative",
				values: {	a : "Positive",
						b : "Negative",
						m : "Mixed",
						u : "Unknown",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Dimensions",
				values: {	a : "8 mm.",
						e : "16 mm.",
						f : "35 mm.",
						g : "70mm.",
						h : "105 mm.",
						l : "3 x 5 in. (8 x 13 cm.)",
						m : "4 x 6 in. (11 x 15 cm.)",
						o : "6 x 9 in. (16 x 23 cm.)",
						p : "3 1/4 x 7 3/8 in. (9 x 19 cm.)",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 4,
				label : "Reduction ratio range/Reduction ratio",
				values: {	a : "Low (1-16x)",
						b : "Normal (16-30x)",
						c : "High (31-60x)",
						d : "Very high (61-90x)",
						e : "Ultra (90x-)",
						u : "Unknown",
						v : "Reduction ratio varies",
				},
			},
			g : {	start : 9,
				len   : 1,
				label : "Color",
				values: {	b : "Black-and-white",
						c : "Multicolored",
						m : "Mixed",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 10,
				len   : 1,
				label : "Emulsion on film",
				values: {	a : "Silver halide",
						b : "Diazo",
						c : "Vesicular",
						m : "Mixed",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 11,
				len   : 1,
				label : "Quality assurance target(s)",
				values: {	a : "1st gen. master",
						b : "Printing master",
						c : "Service copy",
						m : "Mixed generation",
						u : "Unknown",
				},
			},
			j : {	start : 12,
				len   : 1,
				label : "Base of film",
				values: {	a : "Safety base, undetermined",
						c : "Safety base, acetate undetermined",
						d : "Safety base, diacetate",
						l : "Nitrate base",
						m : "Mixed base",
						n : "Not applicable",
						p : "Safety base, polyester",
						r : "Safety base, mixed",
						t : "Safety base, triacetate",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	m : {
		label     : "Motion Picture",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	a : "Film cartridge",
						f : "Film cassette",
						r : "Film reel",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	b : "Black-and-white",
						c : "Multicolored",
						h : "Hand-colored",
						m : "Mixed",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Motion picture presentation format",
				values: {	a : "Standard sound aperture, reduced frame",
						b : "Nonanamorphic (wide-screen)",
						c : "3D",
						d : "Anamorphic (wide-screen)",
						e : "Other-wide screen format",
						f : "Standard. silent aperture, full frame",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Sound on medium or separate",
				values: {	a : "Sound on medium",
						b : "Sound separate from medium",
						u : "Unknown",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Medium for sound",
				values: {	a : "Optical sound track on motion picture film",
						b : "Magnetic sound track on motion picture film",
						c : "Magnetic audio tape in cartridge",
						d : "Sound disc",
						e : "Magnetic audio tape on reel",
						f : "Magnetic audio tape in cassette",
						g : "Optical and magnetic sound track on film",
						h : "Videotape",
						i : "Videodisc",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Dimensions",
				values: {	a : "Standard 8 mm.",
						b : "Super 8 mm./single 8 mm.",
						c : "9.5 mm.",
						d : "16 mm.",
						e : "28 mm.",
						f : "35 mm.",
						g : "70 mm.",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 8,
				len   : 1,
				label : "Configuration of playback channels",
				values: {	k : "Mixed",
						m : "Monaural",
						n : "Not applicable",
						q : "Multichannel, surround or quadraphonic",
						s : "Stereophonic",
						u : "Unknown",
						z : "Other",
				},
			},
			j : {	start : 9,
				len   : 1,
				label : "Production elements",
				values: {	a : "Work print",
						b : "Trims",
						c : "Outtakes",
						d : "Rushes",
						e : "Mixing tracks",
						f : "Title bands/inter-title rolls",
						g : "Production rolls",
						n : "Not applicable",
						z : "Other",
				},
			},
		},
	},
	k : {
		label     : "Non-projected Graphic",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	c : "Collage",
						d : "Drawing",
						e : "Painting",
						f : "Photo-mechanical print",
						g : "Photonegative",
						h : "Photoprint",
						i : "Picture",
						j : "Print",
						l : "Technical drawing",
						n : "Chart",
						o : "Flash/activity card",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	a : "One color",
						b : "Black-and-white",
						c : "Multicolored",
						h : "Hand-colored",
						m : "Mixed",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Primary support material",
				values: {	a : "Canvas",
						b : "Bristol board",
						c : "Cardboard/illustration board",
						d : "Glass",
						e : "Synthetics",
						f : "Skins",
						g : "Textile",
						h : "Metal",
						m : "Mixed collection",
						o : "Paper",
						p : "Plaster",
						q : "Hardboard",
						r : "Porcelain",
						s : "Stone",
						t : "Wood",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Secondary support material",
				values: {	a : "Canvas",
						b : "Bristol board",
						c : "Cardboard/illustration board",
						d : "Glass",
						e : "Synthetics",
						f : "Skins",
						g : "Textile",
						h : "Metal",
						m : "Mixed collection",
						o : "Paper",
						p : "Plaster",
						q : "Hardboard",
						r : "Porcelain",
						s : "Stone",
						t : "Wood",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	g : {
		label     : "Projected Graphic",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	c : "Film cartridge",
						d : "Filmstrip",
						f : "Film filmstrip type",
						o : "Filmstrip roll",
						s : "Slide",
						t : "Transparency",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	b : "Black-and-white",
						c : "Multicolored",
						h : "Hand-colored",
						m : "Mixed",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Base of emulsion",
				values: {	d : "Glass",
						e : "Synthetics",
						j : "Safety film",
						k : "Film base, other than safety film",
						m : "Mixed collection",
						o : "Paper",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Sound on medium or separate",
				values: {	a : "Sound on medium",
						b : "Sound separate from medium",
						u : "Unknown",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Medium for sound",
				values: {	a : "Optical sound track on motion picture film",
						b : "Magnetic sound track on motion picture film",
						c : "Magnetic audio tape in cartridge",
						d : "Sound disc",
						e : "Magnetic audio tape on reel",
						f : "Magnetic audio tape in cassette",
						g : "Optical and magnetic sound track on film",
						h : "Videotape",
						i : "Videodisc",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Dimensions",
				values: {	a : "Standard 8 mm.",
						b : "Super 8 mm./single 8 mm.",
						c : "9.5 mm.",
						d : "16 mm.",
						e : "28 mm.",
						f : "35 mm.",
						g : "70 mm.",
						j : "2 x 2 in. (5 x 5 cm.)",
						k : "2 1/4 x 2 1/4 in. (6 x 6 cm.)",
						s : "4 x 5 in. (10 x 13 cm.)",
						t : "5 x 7 in. (13 x 18 cm.)",
						v : "8 x 10 in. (21 x 26 cm.)",
						w : "9 x 9 in. (23 x 23 cm.)",
						x : "10 x 10 in. (26 x 26 cm.)",
						y : "7 x 7 in. (18 x 18 cm.)",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 8,
				len   : 1,
				label : "Secondary support material",
				values: {	c : "Cardboard",
						d : "Glass",
						e : "Synthetics",
						h : "metal",
						j : "Metal and glass",
						k : "Synthetics and glass",
						m : "Mixed collection",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	r : {
		label     : "Remote-sensing Image",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: { u : "Unspecified" },
			},
			d : {	start : 3,
				len   : 1,
				label : "Altitude of sensor",
				values: {	a : "Surface",
						b : "Airborne",
						c : "Spaceborne",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Attitude of sensor",
				values: {	a : "Low oblique",
						b : "High oblique",
						c : "Vertical",
						n : "Not applicable",
						u : "Unknown",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Cloud cover",
				values: {	0 : "0-09%",
						1 : "10-19%",
						2 : "20-29%",
						3 : "30-39%",
						4 : "40-49%",
						5 : "50-59%",
						6 : "60-69%",
						7 : "70-79%",
						8 : "80-89%",
						9 : "90-100%",
						n : "Not applicable",
						u : "Unknown",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Platform construction type",
				values: {	a : "Balloon",
						b : "Aircraft-low altitude",
						c : "Aircraft-medium altitude",
						d : "Aircraft-high altitude",
						e : "Manned spacecraft",
						f : "Unmanned spacecraft",
						g : "Land-based remote-sensing device",
						h : "Water surface-based remote-sensing device",
						i : "Submersible remote-sensing device",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Platform use category",
				values: {	a : "Meteorological",
						b : "Surface observing",
						c : "Space observing",
						m : "Mixed uses",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 8,
				len   : 1,
				label : "Sensor type",
				values: {	a : "Active",
						b : "Passive",
						u : "Unknown",
						z : "Other",
				},
			},
			j : {	start : 9,
				len   : 2,
				label : "Data type",
				values: {	nn : "Not applicable",
						uu : "Unknown",
						zz : "Other",
						aa : "Visible light",
						da : "Near infrared",
						db : "Middle infrared",
						dc : "Far infrared",
						dd : "Thermal infrared",
						de : "Shortwave infrared (SWIR)",
						df : "Reflective infrared",
						dv : "Combinations",
						dz : "Other infrared data",
						ga : "Sidelooking airborne radar (SLAR)",
						gb : "Synthetic aperture radar (SAR-single frequency)",
						gc : "SAR-multi-frequency (multichannel)",
						gd : "SAR-like polarization",
						ge : "SAR-cross polarization",
						gf : "Infometric SAR",
						gg : "Polarmetric SAR",
						gu : "Passive microwave mapping",
						gz : "Other microwave data",
						ja : "Far ultraviolet",
						jb : "Middle ultraviolet",
						jc : "Near ultraviolet",
						jv : "Ultraviolet combinations",
						jz : "Other ultraviolet data",
						ma : "Multi-spectral, multidata",
						mb : "Multi-temporal",
						mm : "Combination of various data types",
						pa : "Sonar-water depth",
						pb : "Sonar-bottom topography images, sidescan",
						pc : "Sonar-bottom topography, near-surface",
						pd : "Sonar-bottom topography, near-bottom",
						pe : "Seismic surveys",
						pz : "Other acoustical data",
						ra : "Gravity anomales (general)",
						rb : "Free-air",
						rc : "Bouger",
						rd : "Isostatic",
						sa : "Magnetic field",
						ta : "Radiometric surveys",
				},
			},
		},
	},
	s : {
		label     : "Sound Recording",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	d : "Sound disc",
						e : "Cylinder",
						g : "Sound cartridge",
						i : "Sound-track film",
						q : "Roll",
						s : "Sound cassette",
						t : "Sound-tape reel",
						u : "Unspecified",
						w : "Wire recording",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Speed",
				values: {	a : "16 rpm",
						b : "33 1/3 rpm",
						c : "45 rpm",
						d : "78 rpm",
						e : "8 rpm",
						f : "1.4 mps",
						h : "120 rpm",
						i : "160 rpm",
						k : "15/16 ips",
						l : "1 7/8 ips",
						m : "3 3/4 ips",
						o : "7 1/2 ips",
						p : "15 ips",
						r : "30 ips",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Configuration of playback channels",
				values: {	m : "Monaural",
						q : "Quadraphonic",
						s : "Stereophonic",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Groove width or pitch",
				values: {	m : "Microgroove/fine",
						n : "Not applicable",
						s : "Coarse/standard",
						u : "Unknown",
						z : "Other",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Dimensions",
				values: {	a : "3 in.",
						b : "5 in.",
						c : "7 in.",
						d : "10 in.",
						e : "12 in.",
						f : "16 in.",
						g : "4 3/4 in. (12 cm.)",
						j : "3 7/8 x 2 1/2 in.",
						o : "5 1/4 x 3 7/8 in.",
						s : "2 3/4 x 4 in.",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Tape width",
				values: {	l : "1/8 in.",
						m : "1/4in.",
						n : "Not applicable",
						o : "1/2 in.",
						p : "1 in.",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 8,
				len   : 1,
				label : "Tape configuration ",
				values: {	a : "Full (1) track",
						b : "Half (2) track",
						c : "Quarter (4) track",
						d : "8 track",
						e : "12 track",
						f : "16 track",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			m : {	start : 12,
				len   : 1,
				label : "Special playback",
				values: {	a : "NAB standard",
						b : "CCIR standard",
						c : "Dolby-B encoded, standard Dolby",
						d : "dbx encoded",
						e : "Digital recording",
						f : "Dolby-A encoded",
						g : "Dolby-C encoded",
						h : "CX encoded",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			n : {	start : 13,
				len   : 1,
				label : "Capture and storage",
				values: {	a : "Acoustical capture, direct storage",
						b : "Direct storage, not acoustical",
						d : "Digital storage",
						e : "Analog electrical storage",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	f : {
		label     : "Tactile Material",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: {	a : "Moon",
						b : "Braille",
						c : "Combination",
						d : "Tactile, with no writing system",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 2,
				label : "Class of braille writing",
				values: {	a : "Literary braille",
						b : "Format code braille",
						c : "Mathematics and scientific braille",
						d : "Computer braille",
						e : "Music braille",
						m : "Multiple braille types",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Level of contraction",
				values: {	a : "Uncontracted",
						b : "Contracted",
						m : "Combination",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			f : {	start : 6,
				len   : 3,
				label : "Braille music format",
				values: {	a : "Bar over bar",
						b : "Bar by bar",
						c : "Line over line",
						d : "Paragraph",
						e : "Single line",
						f : "Section by section",
						g : "Line by line",
						h : "Open score",
						i : "Spanner short form scoring",
						j : "Short form scoring",
						k : "Outline",
						l : "Vertical score",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			g : {	start : 9,
				len   : 1,
				label : "Special physical characteristics",
				values: {	a : "Print/braille",
						b : "Jumbo or enlarged braille",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
	v : {
		label     : "Videorecording",
		subfields : {
			b : {	start : 1,
				len   : 1,
				label : "SMD",
				values: { 	c : "Videocartridge",
						d : "Videodisc",
						f : "Videocassette",
						r : "Videoreel",
						u : "Unspecified",
						z : "Other",
				},
			},
			d : {	start : 3,
				len   : 1,
				label : "Color",
				values: {	b : "Black-and-white",
						c : "Multicolored",
						m : "Mixed",
						n : "Not applicable",
						u : "Unknown",
						z : "Other",
				},
			},
			e : {	start : 4,
				len   : 1,
				label : "Videorecording format",
				values: {	a : "Beta",
						b : "VHS",
						c : "U-matic",
						d : "EIAJ",
						e : "Type C",
						f : "Quadruplex",
						g : "Laserdisc",
						h : "CED",
						i : "Betacam",
						j : "Betacam SP",
						k : "Super-VHS",
						m : "M-II",
						o : "D-2",
						p : "8 mm.",
						q : "Hi-8 mm.",
						u : "Unknown",
						v : "DVD",
						z : "Other",
				},
			},
			f : {	start : 5,
				len   : 1,
				label : "Sound on medium or separate",
				values: {	a : "Sound on medium",
						b : "Sound separate from medium",
						u : "Unknown",
				},
			},
			g : {	start : 6,
				len   : 1,
				label : "Medium for sound",
				values: {	a : "Optical sound track on motion picture film",
						b : "Magnetic sound track on motion picture film",
						c : "Magnetic audio tape in cartridge",
						d : "Sound disc",
						e : "Magnetic audio tape on reel",
						f : "Magnetic audio tape in cassette",
						g : "Optical and magnetic sound track on motion picture film",
						h : "Videotape",
						i : "Videodisc",
						u : "Unknown",
						z : "Other",
				},
			},
			h : {	start : 7,
				len   : 1,
				label : "Dimensions",
				values: {	a : "8 mm.",
						m : "1/4 in.",
						o : "1/2 in.",
						p : "1 in.",
						q : "2 in.",
						r : "3/4 in.",
						u : "Unknown",
						z : "Other",
				},
			},
			i : {	start : 8,
				len   : 1,
				label : "Configuration of playback channel",
				values: {	k : "Mixed",
						m : "Monaural",
						n : "Not applicable",
						q : "Multichannel, surround or quadraphonic",
						s : "Stereophonic",
						u : "Unknown",
						z : "Other",
				},
			},
		},
	},
};
