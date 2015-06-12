MODULE T; (** AUTHOR ""; PURPOSE ""; *)

PROCEDURE Test*;
BEGIN
	TRACE("Test");
END Test;
	
END T.


Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym 
T.Mod ~