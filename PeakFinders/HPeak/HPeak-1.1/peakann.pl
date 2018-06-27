#!/usr/bin/perl

################################################### #####################
##########################################################
###  directory structure#################
#### fold structure################################
#### .\
#### ..\
#### data\refFlat.out
#### data\phastCons\
####                   chr1.out
####                   chr2.out
####                   ...
#### data\chromFa\     ###available at genome.ucsc
####                 chr1.fa
####                 chr2.fa
####                 ...
#### peakann.pl
#################################################################
####written by Jianjun############################################
##################################################################

use Getopt::Std;
use Cwd qw(realpath);
use File::Basename;
my %Options;
sub hitsLookUp;
sub geneLookUp;
sub peak_CleanUp;
sub refGene_CleanUp;
sub getSeq;
sub strToNums;
sub getPhastCons;
sub sum;
sub mean;
sub stddev;
sub variance;

my $script_path=realpath($0);

my($ef, $dir) = fileparse($script_path);

getopts('aro:', \%Options);

my @result=();
my $out=();

if(defined $Options{"a"}) {
	@result=geneLookUp(@ARGV);
	
} elsif(defined $Options{"r"}) {
	@result=hitsLookUp(@ARGV);
}
else {
	print "USAGE: program -a -o output peak_file for peak annotation\n";
	print "   or: program -r -o output location_files upstream_distance downstream_distance for read census\n";
	exit 0;
}

if(defined $Options{"o"}) {
	open(OUT,">$Options{'o'}") || die "Error:$!\n";
	map {print OUT $_,"\n"} @result;
	close(OUT);
} else {
	map {print $_,"\n"} @result;
}
exit 0;


####################################################################
#######FUNCTIONS###################################################
sub hitsLookUp {
	my ($location_f, $up_cut,$down_cut)=@_;
	my $gene1=do { local(@ARGV, $/) = "$dir\/data\/refFlat.out"; <>};
	$gene1=~s/\r//g;
	my @genes=split /\n/,$gene1;
	my @new_genes=();
	my %lfs=();
	local $|=1;

	undef $gene1;
	###parse read file
	print "Reading location files...\n";
	open(IN,"<$location_f") || die "Error:$!\n";
	while(<IN>) {
		chomp;
		@_=split /\t/;
		$lfs{$_[0]}=$_[1];
	}
	close(IN);
	my @peaks=@labels=();

	foreach $file (keys %lfs) {
		print "File $file...";
		push(@labels,$file);
		open(IN,"<$lfs{$file}") || die "Error:$!\n";
		my @reads=<IN>;
		close(IN);
		foreach my $read (@reads) {
			chomp($read);
			@_=split /\t/,$read;
			my $chr=shift;
			foreach(@_) {
				push(@peaks,[($chr,$_<1?1:$_,$_+300,$file)]);
			}
		}
		print "Done!\n";
	}
	@peaks=sort {$$a[0]<=>$$b[0] || $$a[1]<=>$$b[1]} @peaks;


	#divide reads into arrays, one array per chromosome
	foreach my $peak (@peaks) {
		my ($chr,$start,$end,$label)=@$peak;
		push @$chr,[($start,$end,$label)];
	}
	undef @peaks;
	print "Total # of refGenes: ",scalar(@genes),"\nThe # of processed genes: ";
	push(@new_genes,"NAME\tAcc\tLoc\tStrand\t".join("\t",@labels));
	for(my $j=0;$j<=$#genes;$j++) {
		print "$j..." if($j %2000 == 0);
		my @ele=split /\t/,$genes[$j];
		my $start=$end=0;
		my ($name,$acc,$chr,$strand,$loc1,$loc2)=@ele[0..5];
		my $new_g="$name\t$acc\tchr$chr:$loc1-$loc2\t$strand";
		if($strand eq "+") {
			$start=$loc1-$up_cut; ### upstream to TSS
			$start=1 if($start<1);
			$end=$loc1+$down_cut; ###$end=TSS+downstream
		}
		else {
			$start=$loc2-$down_cut; #downstream to TSS
			$end=$loc2+$up_cut #tss+upstream;
		}
		my $prev=-1;
		my $found=0;
		my %found_per_file=();
		for(my $i=0;$i<scalar(@$chr);$i++) {
			next if($start>$$chr[$i][1]);
			$prev=$i if($prev<0);
			if($end<$$chr[$i][0]) {
				@$chr=@$chr[$prev..(scalar(@$chr)-1)];
				last;
			}
			$found++;
			$found_per_file{$$chr[$i][2]}++;
		}
		if($found) {
			foreach(@labels) {
				$new_g.="\t$found_per_file{$_}";
			}
			push(@new_genes,$new_g);
		}
	}
	###destroy arrays
	foreach(0..24) {
		undef @$_ if(defined @$_);
	}
	print "Done...\n";
	return @new_genes;
}

###this function is to find genome mapping information for each peak
sub geneLookUp {
	my $peak_f=shift;
	local $|=1;
	print "Collecting peaks and refGenes...\n";
	my @peaks=peak_CleanUp($peak_f);
	my $gene1=do { local( @ARGV, $/ ) = "$dir\/data\/refFlat.out"; <> };
	$gene1=~s/\r//g;
	my @genes=split /\n/,$gene1;
	undef $gene1;
	#replace input file extension
	$peak_f =~ s/\.\w+$/\.cscore/;
	
	my $pre_chr=0;
	my @peak_arr=();
	foreach(@genes) {
		my @tmp=split /\t/,$_;
		push(@{$tmp[2]},[(@tmp[0..1],@tmp[3..$#tmp])]);
	}
	#locate annotation for each peak
	print "Done!\nProcessing chromosome: ";
	
	open(FS,">$peak_f") || die "Score Output Error: $!\n";
	print FS "chr\tstart\tend\tMasked%\tphastCons scores\n";
	push(@peak_arr,"Chromosome\tCoverage\tHeight\tGC%\tMasked bases%\tConservation score\tLocation\tGeneName\tGB Acc\tStrand\tDistance\tGeneName\tGB Acc\tStrand\tDistance");
	foreach my $peak (@peaks) {
		chomp($peak);
		my ($chr,$start,$end,$len,$height)=split /\t/,$peak;
		my $chr_o="chr".$chr;
		if($chr_o eq "chr23") {
			$chr_o = "chrX";
		}
		elsif($chr_o eq "chr24") {
			$chr_o="chrY";
		}
		my ($mask_perc,$gc_perc)=getSeq($chr_o,$start,$end);

		if($pre_chr ne $chr) {
			print "$chr...";
			for(my $k=$pre_chr;$k<$chr;$k++) {
				undef @$k;
			}
			close(FH) if(defined FH);
			open(FH,"<$dir\/data\/phastCons\/$chr_o.out") || die "PhastCons file error: $!\n";
			$pre_chr=$chr;
		}
		my @cons_score=getPhastCons(*FH,$chr_o,$start,$end);
		my $conscore="No conservation score";
		my $mean=pop(@cons_score);
		my $std=pop(@cons_score);
		if($std ne "NA") {
			$conscore=$mean."+/-".$std;###
		}

		my $annot="chr".$chr.":".$start."-".$end."\t$len\t$height\tGC%: ".$gc_perc."\tMasked%: ".$mask_perc."\t".$conscore."\t";
		print FS "chr".$chr."\t".$start."\t".$end."\t$mask_perc\t",join(",",@cons_score),"\n";
		my $j;
		for($j=0;$j<scalar(@$chr);$j++) {
			next if(($j<scalar(@$chr)-1) && $start>=$$chr[$j+1][4]);
			my @cur=@{$$chr[$j]};
			if($j<scalar(@$chr)-1) {
				my @next=@{$$chr[$j+1]};
				if($start>=$cur[4]) {
					if($end<=$next[3]) {
						$annot.="Between Genes\t$cur[0]\t$cur[1]\t$cur[2]\t".($start-$cur[4])."\t";
						$annot.="$next[0]\t$next[1]\t$next[2]\t".($next[3]-$end);
						last;
					}
					else {
						next;
					}
				}
			}
			else {
				if($start>=$cur[4]) {
					$annot.="Near Chr. End\t$cur[0]\t$cur[1]\t$cur[2]\t".($start-$cur[4]);
					last;
				}
			}
			if($end<=$cur[3]) {
				$annot.="Near Chr. start\t$cur[0]\t$cur[1]\t$cur[2]\t".($cur[3]-$end);
			}
			else{
				if($start<=$cur[3] && $end>=$cur[4]) {
					$annot.="$len\t$height\t";
					$annot.="Covers entire gene\t$cur[0]\t$cur[1]\t$cur[2]";
				}
				elsif($cur[3]<=$start && $cur[4]>=$end) {
					my @utr=($cur[3],$cur[6],$cur[5],$cur[4]);
					my @exon_start=split /\,/,$cur[8];
					my @exon_end=split /\,/,$cur[9];
					my $found=0;
					for(my $k=0;$k<$cur[7];$k++) {
						my @jnk=($start,$end,$exon_start[$k],$exon_end[$k]);
						@jnk=sort {$a<=>$b} @jnk;
						if(($jnk[3]-$jnk[0])<($end-$start+$exon_end[$k]-$exon_start[$k])) {
							$annot.="Exon\t$cur[0]\t$cur[1]\t$cur[2]";
							$found=1;
							last;
						}
					}
					if(!$found) {
					for(my $k=0;$k<2;$k++) {
						my @jnk=($start,$end,$utr[$k],$utr[$k+2]);
						@jnk=sort {$a<=>$b} @jnk;
						if(($jnk[3]-$jnk[0])<($end-$start+$utr[$k+2]-$utr[$k])) {
							$annot.="5'/3'UTR\t$cur[0]\t$cur[1]\t$cur[2]";
							$found=1;
							last;
						}
					}
					}
					if(!$found) {
						$annot.="Intron\t$cur[0]\t$cur[1]\t$cur[2]";
					}
				}
				else {
					if(($cur[2] eq "+" && $start<$cur[3]) || ($cur[2] eq "-" && $end>$cur[4])) {
						$annot.="Promoter/5'UTR\t$cur[0]\t$cur[1]\t$cur[2]";
					}
					else {
						$annot.="3'UTR/Gene End\t$cur[0]\t$cur[1]\t$cur[2]";
					}
				}
			}
			last;
		}
		push(@peak_arr,$annot);
		@$chr=@$chr[$j..(scalar(@$chr)-1)];
	}
	#free up memory
	foreach($pre_chr..24) {
		undef @$_;
	}
	close(FH) if(defined FH);
	close(FS);
	print "Done!\n";
	return @peak_arr;
}

#clean up refflat.txt, this code clean up some genes with duplicated names
sub refGene_CleanUp {
	my $ref_f=shift;
	my %uniq=();
	my @genes=do {local @ARGV=$ref_f;<>};
	foreach  my $gene (@genes) {
		chomp($gene);
		@_=split /\t/,$gene;
		next if($_[2]=~/_/);
		$_[2]=~s/chr//;
		$_[2]=23 if($_[2] eq "X");
		$_[2]=24 if($_[2] eq "Y");
		my $id=$_[0]."#"."$_[2].$_[4]";
		if(! $uniq{$id}) {
			$uniq{$id}=[@_[1..10]];
		}
		else {
			$uniq{$id}=[@_[1..10]] if (($_[5]-$_[4])>=($uniq{$id}[4]-$uniq{$id}[3]));
		}
	}
	@genes=();
	foreach (sort {$uniq{$a}[1]<=>$uniq{$b}[1] || $uniq{$a}[3]<=>$uniq{$b}[3] ||$uniq{$a}[0] cmp $uniq{$b}[0]} keys %uniq) {
		my $tmp=$_;
		$tmp=~s/\#.*//;
		push(@genes,[($tmp,@{$uniq{$_}})]);
	}
	return @genes;
}

#clean up peak file and return sorted peaks
sub peak_CleanUp {
	my $peak_f=shift;
	my @peaks=do {local @ARGV=$peak_f;<>};

	#sort peaks by chromosome and start position
	@peaks=sort {my @jnk1=split /\t/,$a; my @jnk2=split /\t/,$b;$jnk1[0]<=>$jnk2[0] || $jnk1[1]<=>$jnk2[1]} @peaks;
	return @peaks;
}

sub getSeq {
	my ($chr,$start,$end)=@_;
	open(IN1,"<$dir\/data\/chromFa\/$chr\.fa") || die "can not open chromosome seq file\n";
	my $offset=1+length($chr);
	$start=1 if($start<1);
	my $buffer="";
	seek(IN1, $start+$offset+int($start/50),0);
	read(IN1,$buffer,$end-$start+1+int($end/50)-int($start/50));
	close(IN1);
	$buffer=~s/\s//g;
	my $masked_seq=()=$buffer=~/[Nacgt]/g;
	my $gc=()=$buffer=~/[GC]/gi;
	return (sprintf("%.1f",$masked_seq/length($buffer)*100),sprintf("%.1f",$gc/length($buffer)*100));
}

sub strToNums {
	my $str=shift;
	my @all=();
	my @val=();
	foreach(unpack("C*",$str)) {
		if($_==152) {
			push(@all,"N");
		}
		else {
			push(@all,($_-32)/100);
			push(@val,($_-32)/100);
		}
	}
	if(scalar(@val)>2) {
		push(@all,round(stddev(@val),2),round(mean(@val),2));
	} else {
		@all=("No conservation score","NA","NA");
	}
	return @all;
}

sub getPhastCons {
	my ($fh,$chr,$start,$end)=@_;
	my $buffer="";
	seek($fh,$start-1,0);
	read($fh,$buffer,$end-$start+1);
	return strToNums($buffer);
}

sub round {
	my ($num,$power)=@_;
	return int($num*(10**$power)+0.5)/(10**$power);
}

sub sum
{
	return unless @_;
	return $_[0] unless @_ > 1;
	my $sum;
	foreach(@_) { $sum+= $_; }
	return $sum;
}

sub mean
{
	return unless @_;
	return $_[0] unless @_ > 1;
	return sum(@_)/scalar(@_);
}
sub variance
{
	return unless @_;
	return 0 unless @_ > 1;
	my $mean= mean @_;
	return (sum map { ($_ - $mean)**2 } @_) / $#_;
}
sub stddev
{
	return unless @_;
	return 0 unless @_ > 1;
	return sqrt variance @_;
}
