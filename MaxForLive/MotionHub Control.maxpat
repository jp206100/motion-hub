{
	"patcher" : 	{
		"fileversion" : 1,
		"appversion" : 		{
			"major" : 8,
			"minor" : 6,
			"revision" : 0,
			"architecture" : "x64",
			"modernui" : 1
		},
		"classnamespace" : "box",
		"rect" : [ 100.0, 100.0, 800.0, 600.0 ],
		"bglocked" : 0,
		"openinpresentation" : 1,
		"default_fontsize" : 12.0,
		"default_fontface" : 0,
		"default_fontname" : "Arial",
		"gridonopen" : 1,
		"gridsize" : [ 15.0, 15.0 ],
		"gridsnaponopen" : 1,
		"objectsnaponopen" : 1,
		"statusbarvisible" : 2,
		"toolbarvisible" : 1,
		"lefttoolbarpinned" : 0,
		"toptoolbarpinned" : 0,
		"righttoolbarpinned" : 0,
		"bottomtoolbarpinned" : 0,
		"toolbars_unpinned_last_save" : 0,
		"tallnewobj" : 0,
		"boxanimatetime" : 200,
		"enablehscroll" : 1,
		"enablevscroll" : 1,
		"devicewidth" : 0.0,
		"description" : "Control MotionHub visuals via OSC",
		"digest" : "8-parameter OSC controller for MotionHub",
		"tags" : "OSC, VJ, visuals, control",
		"style" : "",
		"subpatcher_template" : "",
		"assistshowspatchername" : 0,
		"boxes" : [ 			{
				"box" : 				{
					"id" : "obj-title",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 15.0, 10.0, 200.0, 20.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 10.0, 5.0, 200.0, 20.0 ],
					"text" : "MotionHub Control",
					"fontface" : 1,
					"fontsize" : 14.0
				}

			},
			{
				"box" : 				{
					"id" : "obj-status",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 220.0, 10.0, 150.0, 20.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 220.0, 5.0, 150.0, 20.0 ],
					"text" : "→ localhost:9000",
					"fontsize" : 10.0,
					"textcolor" : [ 0.5, 0.5, 0.5, 1.0 ]
				}

			},
			{
				"box" : 				{
					"id" : "obj-udpsend",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 400.0, 500.0, 135.0, 22.0 ],
					"text" : "udpsend localhost 9000"
				}

			},
			{
				"box" : 				{
					"id" : "obj-intensity-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 30.0, 60.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 10.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Intensity",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "Intensity",
							"parameter_type" : 0,
							"parameter_unitstyle" : 5
						}

					},
					"varname" : "intensity"
				}

			},
			{
				"box" : 				{
					"id" : "obj-intensity-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 30.0, 120.0, 130.0, 22.0 ],
					"text" : "/motionhub/intensity $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-glitch-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 110.0, 60.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 60.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Glitch",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "Glitch",
							"parameter_type" : 0,
							"parameter_unitstyle" : 5
						}

					},
					"varname" : "glitch"
				}

			},
			{
				"box" : 				{
					"id" : "obj-glitch-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 110.0, 120.0, 120.0, 22.0 ],
					"text" : "/motionhub/glitch $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-speed-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 190.0, 60.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 110.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Speed",
							"parameter_mmin" : 1.0,
							"parameter_mmax" : 4.0,
							"parameter_shortname" : "Speed",
							"parameter_type" : 1,
							"parameter_unitstyle" : 9,
							"parameter_steps" : 4
						}

					},
					"varname" : "speed"
				}

			},
			{
				"box" : 				{
					"id" : "obj-speed-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 190.0, 120.0, 115.0, 22.0 ],
					"text" : "/motionhub/speed $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-colorshift-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 270.0, 60.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 160.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Color Shift",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "Color",
							"parameter_type" : 0,
							"parameter_unitstyle" : 5
						}

					},
					"varname" : "colorshift"
				}

			},
			{
				"box" : 				{
					"id" : "obj-colorshift-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 270.0, 120.0, 135.0, 22.0 ],
					"text" : "/motionhub/colorshift $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-freqmin-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 30.0, 180.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 220.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Freq Min",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "FreqMin",
							"parameter_type" : 0,
							"parameter_unitstyle" : 1
						}

					},
					"varname" : "freqmin"
				}

			},
			{
				"box" : 				{
					"id" : "obj-freqmin-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 30.0, 240.0, 125.0, 22.0 ],
					"text" : "/motionhub/freqmin $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-freqmax-dial",
					"maxclass" : "live.dial",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "float" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 110.0, 180.0, 44.0, 48.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 270.0, 30.0, 44.0, 48.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Freq Max",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "FreqMax",
							"parameter_type" : 0,
							"parameter_unitstyle" : 1
						}

					},
					"varname" : "freqmax"
				}

			},
			{
				"box" : 				{
					"id" : "obj-freqmax-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 110.0, 240.0, 130.0, 22.0 ],
					"text" : "/motionhub/freqmax $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-mono-toggle",
					"maxclass" : "live.toggle",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 190.0, 180.0, 24.0, 24.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 330.0, 40.0, 24.0, 24.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Monochrome",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "Mono",
							"parameter_type" : 2
						}

					},
					"varname" : "monochrome"
				}

			},
			{
				"box" : 				{
					"id" : "obj-mono-label",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 190.0, 205.0, 50.0, 20.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 320.0, 62.0, 44.0, 20.0 ],
					"text" : "Mono",
					"fontsize" : 10.0,
					"textjustification" : 1
				}

			},
			{
				"box" : 				{
					"id" : "obj-mono-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 190.0, 240.0, 140.0, 22.0 ],
					"text" : "/motionhub/monochrome $1"
				}

			},
			{
				"box" : 				{
					"id" : "obj-reset-button",
					"maxclass" : "live.button",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 270.0, 180.0, 24.0, 24.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 375.0, 40.0, 24.0, 24.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_longname" : "Reset",
							"parameter_mmax" : 1.0,
							"parameter_shortname" : "Reset",
							"parameter_type" : 2
						}

					},
					"varname" : "reset"
				}

			},
			{
				"box" : 				{
					"id" : "obj-reset-label",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 270.0, 205.0, 50.0, 20.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 365.0, 62.0, 44.0, 20.0 ],
					"text" : "Reset",
					"fontsize" : 10.0,
					"textjustification" : 1
				}

			},
			{
				"box" : 				{
					"id" : "obj-reset-osc",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 270.0, 240.0, 110.0, 22.0 ],
					"text" : "/motionhub/reset 1"
				}

			}
		],
		"lines" : [ 			{
				"patchline" : 				{
					"source" : [ "obj-intensity-dial", 0 ],
					"destination" : [ "obj-intensity-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-intensity-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-glitch-dial", 0 ],
					"destination" : [ "obj-glitch-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-glitch-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-speed-dial", 0 ],
					"destination" : [ "obj-speed-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-speed-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-colorshift-dial", 0 ],
					"destination" : [ "obj-colorshift-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-colorshift-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-freqmin-dial", 0 ],
					"destination" : [ "obj-freqmin-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-freqmin-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-freqmax-dial", 0 ],
					"destination" : [ "obj-freqmax-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-freqmax-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-mono-toggle", 0 ],
					"destination" : [ "obj-mono-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-mono-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-reset-button", 0 ],
					"destination" : [ "obj-reset-osc", 0 ]
				}

			},
			{
				"patchline" : 				{
					"source" : [ "obj-reset-osc", 0 ],
					"destination" : [ "obj-udpsend", 0 ]
				}

			}
		],
		"parameters" : 		{
			"obj-intensity-dial" : [ "Intensity", "Intensity", 0 ],
			"obj-glitch-dial" : [ "Glitch", "Glitch", 0 ],
			"obj-speed-dial" : [ "Speed", "Speed", 0 ],
			"obj-colorshift-dial" : [ "Color Shift", "Color", 0 ],
			"obj-freqmin-dial" : [ "Freq Min", "FreqMin", 0 ],
			"obj-freqmax-dial" : [ "Freq Max", "FreqMax", 0 ],
			"obj-mono-toggle" : [ "Monochrome", "Mono", 0 ],
			"obj-reset-button" : [ "Reset", "Reset", 0 ],
			"parameterbanks" : 			{
				"0" : 				{
					"index" : 0,
					"name" : "MotionHub",
					"parameters" : [ "Intensity", "Glitch", "Speed", "Color Shift", "Freq Min", "Freq Max", "Monochrome", "Reset" ]
				}

			},
			"inherited_shortname" : 1
		},
		"dependency_cache" : [  ],
		"autosave" : 0
	}

}
