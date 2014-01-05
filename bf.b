# Interpreter for the canonical esoteric language.
# Compiles to bytecode, no optimizations, done for fun.
# Pete Elmore (pete at debu dot gs), New Year's Day 2014
# Released into the public domain.

implement Bf;

include "sys.m"; sys: Sys;
include "draw.m";
include "arg.m";

Bf: module {
	init: fn(nil: ref Draw->Context, args: list of string);
	ARENASZ: con 1024 * 1024;
	EXIT, INC, DEC, JZ, JNZ, INCP, DECP, READ, WRITE: con iota;
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;

	arg->init(args);
	eflag := 0;
	source := "";
	while ((opt := arg->opt()) != 0) {
		case opt {
		'e' =>
			eflag = 1;
			source = arg->arg();
		* =>
			usage();
		}
	}
	args = arg->argv();
	if(!eflag) {
		if(len args != 1)
			usage();
		else
			source = readfile(hd args);
	}

	code := compile(source);
	execute(code, array[ARENASZ] of { * => byte 0 });
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: bf [program.bf|-e inline-program]");
	raise "fail:usage";
}

compile(p: string): array of int
{
	marks: list of int = nil;
	code := array[len p * 2 + 1] of { * => EXIT };
	pc := 0;
	for(i := 0; i < len p; i++) {
		case p[i] {
		'-' => code[pc++] = DEC;
		'+' => code[pc++] = INC;
		'<' => code[pc++] = DECP;
		'>' => code[pc++] = INCP;
		',' => code[pc++] = READ;
		'.' => code[pc++] = WRITE;
		'[' =>
			code[pc++] = JZ;
			marks = pc++ :: marks;
		']' =>
			if(marks == nil) {
				sys->fprint(sys->fildes(2), "bf: unmatched ']' at character %d.", pc);
				raise "fail:errors";
			}
			c := hd marks;
			marks = tl marks;
			code[pc++] = JNZ;
			code[c] = pc;
			code[pc++] = c;
		}
	}
	if(marks != nil) {
		sys->fprint(sys->fildes(2), "bf: unmatched '['.");
		raise "fail:errors";
	}
	return code;
}

execute(code: array of int, arena: array of byte)
{
	pc := 0;
	p := 0;
	buf := array[1] of byte;
	stopreading := 0;
	for(;;) {
		case code[pc] {
		DEC => arena[p]--;
		INC => arena[p]++;
		DECP =>
			p--;
			if(p < 0)
				p = len arena - 1;
		INCP =>
			p = (p + 1) % len arena;
		READ =>
			arena[p] = byte -1;
			if(!stopreading) {
				n := sys->read(sys->fildes(0), buf, 1);
				if(n < 1)
					stopreading = 1;
				else
					arena[p] = buf[0];
			}
		WRITE =>
			buf[0] = arena[p];
			sys->write(sys->fildes(1), buf, 1);
		JNZ =>
			if(arena[p] != byte 0)
				pc = code[pc + 1];
			else
				pc++;
		JZ =>
			if(arena[p] == byte 0)
				pc = code[pc + 1];
			else
				pc++;
		EXIT => return;
		}
		pc++;
	}
}

readfile(fname: string): string
{
	fd := sys->open(fname, Sys->OREAD);
	if(fd == nil)
		die(fname);

	src := "";
	buf := array[Sys->ATOMICIO] of byte;
	while((n := sys->read(fd, buf, len buf)) > 0) {
		src += string buf[:n];
	}
	return src;
}

die(s: string)
{
	sys->fprint(sys->fildes(2), "bf: %s: %r\n", s);
	raise "fail:errors";
}