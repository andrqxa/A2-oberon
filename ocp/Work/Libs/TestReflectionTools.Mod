MODULE TestReflectionTools; (** AUTHOR ""; PURPOSE ""; *)

IMPORT SYSTEM,ReflectionTools, KernelLog, Strings;

TYPE
	FactoryProcedure* = PROCEDURE(obj:ANY;sender, data : ANY); (*In obj parametr need send pointer to object*)

	TestObj= OBJECT
			PROCEDURE TestMethod(a:Strings.String;b:ANY);
			BEGIN
				KernelLog.String("a= "); KernelLog.String(a^); KernelLog.Ln;
			END TestMethod;
	END TestObj;

	PROCEDURE Test*;
	VAR
	 obj:TestObj;
	 adr:ADDRESS;
	 fp:FactoryProcedure;
	BEGIN
		NEW(obj);
		obj.TestMethod(Strings.NewString("Hello!"),NIL);
		adr:=ReflectionTools.GetMethodByName(obj,'TestMethod');
		fp:=SYSTEM.VAL(FactoryProcedure,adr);
		fp(obj,Strings.NewString("Reflection Hello!"),NIL);
	END Test;
	

END TestReflectionTools.Test~

