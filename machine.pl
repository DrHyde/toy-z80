#!/usr/local/bin/perl -w

use strict;

use CPU::Emulator::Z80;
use Time::HiRes qw(setitimer ITIMER_VIRTUAL ITIMER_REAL);
use Term::ReadKey;
use IO::Scalar;
use Data::Dumper;
use Curses;

use Getopt::Long;
my $clocktick = 0.01;
GetOptions(
    "clocktick" => \$clocktick
);

my $cpu = CPU::Emulator::Z80->new( # RAM is 64K of zeroes
    ports => 256,
);
my $clock = 0; # clock isn't running
my @banks = (
    {
        address => 0x0000,
        type    => 'ROM',
        size    => 0x4000,
        file    => IO::Scalar->new(do {
                       open(my $f, 'loader.o') ||
                           die("Can't read loader.o\n");
                       local $/ = undef;
                       my $rom = <$f>;
                       $rom .= chr(0) x (0x4000 - length($rom));
                       \$rom;
                   }),
    },
    {
        address => 0x4000,
        type    => 'ROM',
        size    => 0x4000,
        file    => IO::Scalar->new(do {
                       open(my $f, 'OS.o') ||
                           die("Can't read OS.o\n");
                       local $/ = undef;
                       my $rom = <$f>;
                       $rom .= chr(0) x (0x4000 - length($rom));
                       \$rom;
                   }),
    }
);
$cpu->memory()->bank(%{$banks[0]}); # boot loader
$cpu->memory()->bank(%{$banks[1]}); # OS

$cpu->add_output_device(address => 0x00, function => \&mem_bank);
$cpu->add_output_device(address => 0x01, function => \&mem_unbank);
$cpu->add_output_device(address => 0x02, function => \&io_wr_stdout);
$cpu->add_output_device(address => 0xFF, function => \&hw_start_clock);

setitimer(ITIMER_VIRTUAL, $clocktick, $clocktick);
$SIG{VTALRM} = sub {
# setitimer(ITIMER_REAL, 0.01, 0.01);
# $SIG{ALRM} = sub {
    if(my $key = ReadKey(-1)) {
        $cpu->{STOPREACHED} = 1;
        warn "Got char $key\n";
    }
    if($clock) {
        $cpu->nmi();
        # print "clock tick";
    }
};

ReadMode 'noecho';
ReadMode 'cbreak';

initscr;
curs_set(0); # hide cursor
my $win = Curses->new;

# y, x; origin is 1,1 top left
$win->addstr(1, 1,  "Registers");
$win->addstr(6, 15, "SZ ½ PAC");
$win->addstr(7, 15, "ie c ada");
$win->addstr(8, 15, "gr a rdr");
$win->addstr(9, 15, "no r //r");
$win->addstr(10, 15, "   r OSy");
$win->addstr(11, 15, "   y vu ");
$win->addstr(5, 1,  "A:");
$win->addstr(5, 10, "F:");
$win->addstr(6, 1,  "BC:");
$win->addstr(7, 1,  "DE:");
$win->addstr(8, 1,  "HL:");

$win->addstr(3, 1, "PC:");
$win->addstr(3, 24, "Stack  SP:");
$win->addstr(5, 42, "(top)");

$win->addstr(16, 24, "Uptime:");

while(!$cpu->stopped()) {
    $cpu->run(1000);
    $win->addstr(3,  5, sprintf("0x%04x", $cpu->register('PC')->get()));
    $win->addstr(5,  5, sprintf("0x%02x", $cpu->register('A')->get()));
    $win->addstr(5, 13, sprintf("0x%08b", $cpu->register('F')->get()));
    $win->addstr(6,  5, sprintf("0x%04x", $cpu->register('BC')->get()));
    $win->addstr(7,  5, sprintf("0x%04x", $cpu->register('DE')->get()));
    $win->addstr(8,  5, sprintf("0x%04x", $cpu->register('HL')->get()));

    my $sp = $cpu->register('SP')->get();
    $win->addstr(3, 35, sprintf("0x%04x", $sp));

    # foreach my $depth (0 .. 9) {
    #     $win->addstr(5 + $depth, 28, sprintf("0x%04x", $sp - $depth * 2));
    #     $win->addstr(5 + $depth, 35, sprintf("0x%04x", $cpu->memory->peek16($sp - $depth * 2)));
    #     $sp = 0x10000 if($sp == 0);
    #  }

    $win->addstr(16, 31, sprintf(
        "0x%02x%02x%02x%02x",
        $cpu->memory->peek(0x0065),
        $cpu->memory->peek(0x0064),
        $cpu->memory->peek(0x0063),
        $cpu->memory->peek(0x0062),
    ));

    $win->refresh();
    select(undef, undef, undef, 0.05);
}

do_reset();

# print Dumper($cpu->memory());
print $cpu->format_registers();

sub mem_bank {
}

sub mem_unbank {
    $cpu->memory()->unbank(address => 0x4000 * $_[0]);
}

sub io_wr_stdout {
    print chr(shift);
}

sub hw_start_clock {
    $clock = 1;
}

my $have_done_reset = 0;
END {
    do_reset() unless($have_done_reset);
}

sub do_reset {
    $have_done_reset++;
    endwin;
    ReadMode 'restore';
    # curs_set(1);
}
