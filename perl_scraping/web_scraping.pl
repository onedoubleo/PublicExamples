#usr/bin/perl

use strict;
use warnings;

#Required Modules
use LWP::Simple;
use POSIX qw(strftime);
use Time::Piece;
use Time::Seconds;
use HTTP::Request::Common;
use Text::CSV;

#Begin Log File for Troubleshooting
open my $logF,'>','logs\\scheduleNewsLog'.strftime("%Y_%m_%d",localtime).'.txt';
print $logF "Beginning Script on ".localtime."\n";

#Get Time Strings for URL
my $ud = strftime("%d",localtime);
my $um = strftime("%m",localtime);
my $cd = strftime("%a",gmtime);
#URL To Scrape:
my $url =  "http://www.dailyfx.com/files/Calendar-".$um."-".$ud."-2020.csv";
#User Agent for Reqwuesting Data
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->default_header('User-Agent' => "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5 (.NET CLR 3.5.30729)",
					);

#GET Request for Data
my $getCal = $ua->request(GET $url);
#Check that Request was Successful and that the Day is Monday
if($getCal->is_success && $cd eq 'Mon')
{	
	print $logF "Successfull Connection ".$getCal->status_line."\n";
	#Split HTML by newline and create csv output for manipulations.
	my @data = split("\n",$getCal->decoded_content);
	my $csv = Text::CSV->new({sep_char => ',', binary => 1});
	#Holder variables for Date, Time, Importance and Currency
	my @d;my @t; my @i; my @c;
	my $j=0; #Counter Variable
	int $lc = 0;
	#Loop through each Line (individual HTML line from website)
	foreach(@data)
	{
		$lc++;
		chomp($_); #Remove whitespace at end of string.
		next if ($_ =~ /Time,Time/); #Skip if HTML contains this line
		$csv->parse($_) or die $_;	#Parse the data line
		#Enter fields to holder arrays
		if($csv->parse($_))
		{
			my @fields = $csv->fields();
			if($fields[0] ne '' && $fields[1] ne '' && $fields[3] ne '' && $fields[5] ne '')
			{
				$d[$j] = $fields[0];
				$t[$j] = $fields[1];
				$i[$j] = $fields[5];
				$c[$j] = uc($fields[3]);
				$j++;	
			}
		}
		else
		{
			print $logF "Couldn't Parse Line "+$lc+"\n";
		}
	}
	#Fix time formats and timezones
	for(my $k=0;$k<$#t;$k++)
	{
		if($t[$k] ne '')
		{
			my $time = addTime($d[$k],$t[$k]);
			$t[$k]  = $time->strftime('%H:%M');
			$d[$k] = $time->strftime("%d/%m/%Y");
		}
	}
	#Stanatise data for output. 
	my($dref,$tref,$iref,$cref) =  &sortEvents(\@d,\@t,\@i,\@c);
	@d = @$dref;
	@t = @$tref;
	@i = @$iref;
	@c = @$cref;
	#Log Calendar for dashboard viewing
	logStats(\@d,\@t,\@i,\@c);
	print $logF "Arrays sorted, scheduling orders\n";
	#Create batch file to schedule each trade based on Oanda API
	my $scriptLoc = 'PlaceNewsOrder.bat';
	for(my $k=0;$k<=$#t;$k++)
	{
		if($i[$k] ne '' && $d[$k] ne '' && $t[$k] ne '' && $c[$k] ne '')
		{
			if($d[$k] !~ /[a-z]/)
			{
				my $schStr;
				if($k<10){
					$schStr = "schtasks /create /tr '$scriptLoc $c[$k] $i[$k]' /tn 'Forex 0$k $c[$k] $i[$k]' /sc once /sd $d[$k] /st $t[$k] /V1 /Z /ru system";
				}
				else{
					$schStr = "schtasks /create /tr '$scriptLoc $c[$k] $i[$k]' /tn 'Forex $k $c[$k] $i[$k]' /sc once /sd $d[$k] /st $t[$k] /V1 /Z /ru system";
				}
				my $result = `$schStr`;
				if($result =~ /SUCCESS/)
				{
					print $logF "\t$d[$k] - $t[$k]\n";
					print $logF "\t\t".$result;
				}
				else
				{
					print $logF "Unsuccesful\n";
					print $logF $result."\n";
					print $logF $schStr."\n";
				}
			}
		}
	}
	print $logF "$#d Events put on for this week\n";
	#End Main Function
}else if($cd eq 'Mon'){
	print $logF "Script Called on Incorrect Day of Week.\n";
}else{
	print $logF "Could Not Connect to URL.\n";
	print $logF $getCal->status_line;
}
#End Success & Day Check
=pod
Example of CSV Output
Thu Dec 11,13:30,GMT,CAD,CAD New Housing Price Index (MoM),Low,,0.1%,0.1%
Thu Dec 11,13:30,GMT,CAD,CAD New Housing Price Index (YoY),Medium,,,1.6%
Thu Dec 11,13:30,GMT,USD,USD Import Price Index (MoM),Low,,-1.8%,-1.3%
Thu Dec 11,13:30,GMT,USD,USD Import Price Index (YoY),Low,,-2.6%,-1.8%
Thu Dec 11,13:30,GMT,CAD,CAD Capacity Utilization Rate,Low,,82.9%,82.7%
Thu Dec 11,13:30,GMT,USD,USD Advance Retail Sales,High,,0.4%,0.3%
Thu Dec 11,13:30,GMT,USD,USD Retail Sales Less Autos,Medium,,0.1%,0.3%
=cut

#Time format and zone handler
sub addTime
{
	my $st = $_[0].' '.$_[1].' '.strftime('%Y',gmtime);
	my $td = Time::Piece->strptime($st,"%a %b %d %H:%M %Y");
	my $nt = $td + ((60*60*2)-60);
	return($nt);
}

#Organise CSV Ouput as some event have same html holder for date/time
sub sortEvents
{
    my @date = @{ $_[0] };
    my @time = @{ $_[1] };
    my @imp = @{ $_[2] };
    my @cur = @{ $_[3] };
	my (@rd,@rt,@ri,@rc);
	my $retC = 0;
	my $i=1;
	my $tc = 0;
	my $m=0;
	#First check the 0th component
	$rd[$m] = $date[0];
	$rt[$m] = $time[0];
	$ri[$m] = $imp[0];
	$rc[$m] = $cur[0];
	$m++;
	#then check for doubles
	while($i>0 && $i<$#date+1)
	{
		if($date[$i] !~ /[[a-z]/)
		{		
			#Exception Catching
			if($date[$i] eq $date[$i-1] && $time[$i] eq $time[$i-1])
			{			
				$tc++;
			}
			else 
			{ 
				$tc = 0;
				$rd[$m] = $date[$i];
				$rt[$m] = $time[$i];
				$ri[$m] = $imp[$i];
				$rc[$m] = $cur[$i];
				$m++;
			}
			if($tc > 0)
			{
				if($tc == 1 && $cur[$i] ne $cur[$i-1])
				{
					$rd[$m] = $date[$i];
					$rt[$m] = $time[$i];
					$ri[$m] = $imp[$i];
					$rc[$m] = $cur[$i];
					$m++;
				}
				elsif(($tc >= 2) && $cur[$i] ne $cur[$i-1] && $cur[$i] ne $cur[$i-2])
				{
					$rd[$m] = $date[$i];
					$rt[$m] = $time[$i];
					$ri[$m] = $imp[$i];
					$rc[$m] = $cur[$i];
					$m++;					
				}
				else
				{
					if($imp[$i] eq 'High')
					{	$ri[$m-1] = 'High'; }
					elsif($ri[$m-1] eq 'Low'  && $imp[$i] eq 'Medium')
					{	$ri[$m-1] = 'Medium'; }
				}
			}
		}
		$i++;
	}
	return(\@rd,\@rt,\@ri,\@rc);
}

#HTML Output of Stats for Each week for review
sub logStats
{
	my @date = @{ $_[0] };
    my @time = @{ $_[1] };
    my @imp = @{ $_[2] };
    my @cur = @{ $_[3] };
	my $dayT=0;my$highT=0;my$midT=0;my$lowT=0;
	my @days = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	open my $statF,'>','schedule.html';
	my $output = << "EOH";
<table class="schedule">
	<caption>Daily Overview</caption>
EOH
	foreach(@days)
	{
		#my ($dayC,$highC,$midC,$lowC) = 0;
		my $dayC=0;my$highC=0;my$midC=0;my$lowC=0;
		my $dy = $_;
		for(my $i=0;$i<$#date;$i++)
		{
			my $day = Time::Piece->strptime($date[$i],"%d/%m/%Y");
			my $abr = $day->strftime('%a');
			
			if($abr eq $dy)
			{
				$dayC++;
				if($imp[$i] eq 'High'){ $highC++;}
				elsif($imp[$i] eq 'Medium') { $midC++; }
				else{ $lowC++; }
			}
		}
		$dayT+=$dayC;
		$highT+=$highC;
		$midT+=$midC;
		$lowT+=$lowC;
		
		$output .= << "EOT";
	<thead>
	<tr><th>$dy:</th><th>Low</th><th>Mid</th><th>Low</th></tr>
	</thead>
	<tr><td>$dayC</td><td>$highC</td><td>$midC</td><td>$lowC</td></tr>
EOT
	}

	$output .= <<"EOR";
	<thead>
	<tr><th>Total:</th><th>High</th><th>Mid</th><th>Low</th></tr>
	</thead>
	<tr><td>$dayT</td><td>$highT</td><td>$midT</td><td>$lowT</td></tr>
</table>

EOR
print $statF $output;
close($statF);
}
