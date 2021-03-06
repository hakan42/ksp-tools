#! /usr/bin/perl -w

use File::Copy qw(move);
use File::Path qw(mkpath);
use File::Temp qw(tempfile);

# TODO Pass working directory as argument
$workdir = ".";

$name = undef;
$version = undef;
$brace_level = 0;

$in_flightstate_section = 0;

$in_scenario_section = 0;
$scenario_number = 0;

# $in_vessel_section = 0;
$vessel_number = 0;

$extract_ships_path = "$workdir/Extracted/Ships";
$extract_scenario_path = "$workdir/Extracted/Scenarios";

open (IN, "< $workdir/persistent.sfs") || die ("Can't open $workdir/persistent.sfs: $!\n");

# Should already exist but you never know...
mkpath("$workdir/Ships/VAB");

# Don't pollute our normal ship storage
mkpath($extract_ships_path);

# Keep Scenarios seperate
mkpath($extract_scenario_path);

while (<IN>)
{
	if (/\{/)
	{
		$brace_level++;
		# if ($in_flightstate_section eq 1)
		# {
		# }
		# if ($in_scenario_section eq 1)
		# {
		# }
		# print "... $in_scenario_section $in_flightstate_section $in_vessel_section $brace_level\n";
	}
	elsif (/\}/)
	{
		$brace_level--;
		if ($in_scenario_section eq 1)
		{
			if ($brace_level eq 1)
			{
				$in_scenario_section = 0;
				if (defined($temp_fh))
				{
					# Keep the last brace...
					print $temp_fh $_;
					close ($temp_fh);
					$temp_fh = undef;
					$final_file_name = $extract_scenario_path . "/" . $name . " - " . $scenario_number . ".sfs";
					# print "Renaming to '" . $final_file_name . "'\n";
					# move ($temp_file_name, $final_file_name);

					open (SCENARIO_IN, "< $temp_file_name") || die ("Can't open $temp_file_name to read: $!\n");
					open (SCENARIO_OUT, "> $final_file_name") || die ("Can't open $final_file_name to read: $!\n");

					while (<SCENARIO_IN>)
					{
						s/^\t//;
						print SCENARIO_OUT $_;
					}

					close (SCENARIO_OUT);
					close (SCENARIO_IN);

					# Set timestamps accordingly...
					($atime, $mtime) = (stat("$workdir/persistent.sfs"))[8,9];
					utime($atime, $mtime, $final_file_name);

					unlink($temp_file_name);
				}
			}
		}

		if ($in_flightstate_section eq 1)
		{
			if ($brace_level eq 1)
			{
			}
			if ($brace_level eq 2)
			{
				# print "Vessel possibly closed\n";
				if (defined($temp_fh))
				{
					# Keep the last brace...
					print $temp_fh $_;
					close ($temp_fh);
					$temp_fh = undef;
					$final_file_name = $extract_ships_path . "/" . $name . " - " . $vessel_number . ".craft";
					# print "Renaming to '" . $final_file_name . "'\n";
					# move ($temp_file_name, $final_file_name);

					open (CRAFT_IN, "< $temp_file_name") || die ("Can't open $temp_file_name to read: $!\n");
					open (CRAFT_OUT, "> $final_file_name") || die ("Can't open $final_file_name to read: $!\n");

					$in_parts_section = 0;
					while (<CRAFT_IN>)
					{
						# TODO appropiate filtering here...
						s/^\t\t\t//;
						if (/^PART/)
						{
							$in_parts_section = 1;
							# print CRAFT_OUT "ship = Comm Sat One\n";
							print CRAFT_OUT "version = $version\n";
							print CRAFT_OUT "description = \n";
							print CRAFT_OUT "type = VAB\n";
						}

						if ($in_parts_section)
						{
							print CRAFT_OUT $_;
						}
						else
						{
							if (/^name = /)
							{
								s/^name/ship/;
								print CRAFT_OUT $_;
							}
							else
							{
								# print CRAFT_OUT "# " . $_;
							}
						}
					}

					close (CRAFT_OUT);
					close (CRAFT_IN);

					# Set timestamps accordingly...
					($atime, $mtime) = (stat("$workdir/persistent.sfs"))[8,9];
					utime($atime, $mtime, $final_file_name);

					unlink($temp_file_name);
				}
			}
		}

		# print "... $in_flightstate_section $in_scenario_section $in_vessel_section $brace_level\n";
	}
	elsif (/^\tversion = /)
	{
		if (!(defined($version)))
		{
			@foo = split(/ = /);
			$version = $foo[1];
			chomp($version);
			# print $version . "\n";
		}
	}
	elsif (/^\tSCENARIO/)
	{
		$in_scenario_section = 1;
		$name = undef;
		$scenario_number++;
		# print "Scenario: $_";
		# print "    $brace_level\n";

		($temp_fh, $temp_file_name) = tempfile(); # DIR => $extract_path_ships
		# print "Writing to $temp_file_name\n";
	}
	elsif (/^\tFLIGHTSTATE/)
	{
		$in_flightstate_section = 1;
	}
	elsif (/^\t\tVESSEL/)
	{
		$name = undef;
		$vessel_number++;
		# print "Vessel: $_";
		# print "    $brace_level\n";

		($temp_fh, $temp_file_name) = tempfile(); # DIR => $extract_path_ships
		# print "Writing to $temp_file_name\n";
	}
	elsif (/^\t\tname = / || /^\t\t\tname = /)
	{
		if (!(defined($name)))
		{
			@foo = split(/ = /);
			$name = $foo[1];
			$name =~ s/[\n\r]$//;
			$name =~ s/[\n\r]$//;
			# print "Name: '" . $name . "'\n";
		}
	}

	if (defined($temp_fh))
	{
		print $temp_fh $_;
	}
}

close (IN);

