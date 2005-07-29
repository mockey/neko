open Printf

type p_style =
	| StyleJava
	| StyleMSVC

let print_style = ref StyleJava

let normalize_path p =
	let l = String.length p in
	if l = 0 then
		"./"
	else match p.[l-1] with 
		| '\\' | '/' -> p
		| _ -> p ^ "/"

let genreport ep (msg,p) etype printer =
	let error_printer file line =
		match !print_style with
		| StyleJava -> sprintf "%s:%d:" file line
		| StyleMSVC -> sprintf "%s(%d):" file line
	in
	let epos = ep error_printer p in
	prerr_endline (sprintf "%s : %s %s" epos etype (printer msg));
	exit 1

let report a b c = genreport Lexer.get_error_pos a b c
(*//let report a b c = genreport Mllexer.get_error_pos a b c*)

let switch_ext file ext =
	try
		Filename.chop_extension file ^ ext
	with
		_ -> file ^ ext

let open_file ?(bin=false) file =
	try 
		if bin then open_in_bin file else open_in file
	with _ -> failwith ("File not found " ^ file)

(*/*
let interp file =
	let ctx = Interp.create ["";normalize_path (Filename.dirname file)] in
	let mname = switch_ext (Filename.basename file) "" in
	try
		ignore(Interp.execute ctx mname Ast.null_pos);
	with
		Interp.Error (Interp.Module_not_found m,_) when m = mname -> 
			failwith ("File not found " ^ file)
*/*)

let compile file =
	let ch = open_file file in
	let ast = Parser.parse (Lexing.from_channel ch) file in
	close_in ch;
	let data = Compile.compile file ast in
	let file = switch_ext file ".n" in
	let ch = IO.output_channel (open_out_bin file) in
	Bytecode.write ch data;
	IO.close_out ch

let dump file =
	let ch = IO.input_channel (open_file ~bin:true file) in
	let data = (try Bytecode.read ch with Bytecode.Invalid_file -> IO.close_in ch; failwith ("Invalid bytecode file " ^ file)) in
	IO.close_in ch;
	let fout = switch_ext file ".txt" in
	let ch = IO.output_channel (open_out fout) in
	Bytecode.dump ch data;
	IO.close_out ch

(*/*
let nekoml file =
	let ctx = Mltyper.context ["";Filename.dirname file ^ "/"] in
	ignore(Mltyper.load_module ctx [String.capitalize (Filename.chop_extension (Filename.basename file))] Mlast.null_pos);
	Hashtbl.iter (fun m e ->
		let e = Mlneko.generate e in
		let file = String.concat "/" m ^ ".neko" in
		let ch = IO.output_channel (open_out file) in
		let ctx = Printer.create ch in
		Printer.print ctx e;
		IO.close_out ch
	) (Mltyper.modules ctx)
*/*)

;;
try	
	let usage = "Neko v0.3 - (c)2005 Nicolas Cannasse\n Usage : neko.exe [options] <files...>\n Options :" in
	let args_spec = [
		("-msvc",Arg.Unit (fun () -> print_style := StyleMSVC),": use MSVC style errors");
(*//	("-x", Arg.String interp,"<file> : interpret neko program"); *)
		("-c", Arg.String compile,"<file> : compile file to NekoVM bytecode");
		("-d", Arg.String dump,"<file> : dump NekoVM bytecode");
(*//	("-nml", Arg.String nekoml,"<file> : compile NekoML file"); *)
	] in
	Arg.parse args_spec (fun file -> raise (Arg.Bad file)) usage;
with	
	| Lexer.Error (m,p) -> report (m,p) "syntax error" Lexer.error_msg
	| Parser.Error (m,p) -> report (m,p) "parse error" Parser.error_msg
	| Compile.Error (m,p) -> report (m,p) "compile error" Compile.error_msg
(*/*| Interp.Error (m,p) -> report (m,p) "runtime error" Interp.error_msg
	| Mllexer.Error (m,p) -> mlreport (m,p) "syntax error" Mllexer.error_msg
	| Mlparser.Error (m,p) -> mlreport (m,p) "parse error" Mlparser.error_msg
	| Mltyper.Error (m,p) -> mlreport (m,p) "type error" Mltyper.error_msg */*)
	| Failure msg ->
		prerr_endline msg;
		exit 1;
