MODULE Files IN Oberon;
IMPORT SYSTEM, Files IN A2;

TYPE
	Position* = Files.Position;
	Size* = Files.Size;
	File* = Files.File;
	Rider* = Files.Rider;

CONST New* = Files.New;;
CONST Old* = Files.Old;
CONST Register* = Files.Register;
CONST Close* = Files.Update;
CONST Length* = Files.Length;
CONST GetDate* = Files.GetDate;
CONST SetDate* = Files.SetDate;;
CONST Set* = Files.Set;
CONST Pos* = Files.Pos;
CONST Base* = Files.Base;

CONST Read* = Files.ReadSystemByte;
CONST ReadBytes* = Files.ReadSystemBytes;
CONST ReadInt* = Files.ReadInt;
CONST ReadLInt* = Files.ReadLInt;
CONST ReadSet* = Files.ReadSet32;
CONST ReadBool* = Files.ReadBool;
CONST ReadReal* = Files.ReadReal;
CONST ReadLReal* = Files.ReadLReal;
CONST ReadString* = Files.ReadString;
CONST ReadNum* = Files.ReadNum;

CONST Write* = Files.WriteSystemByte;
CONST WriteBytes* = Files.WriteSystemBytes;
CONST WriteInt* = Files.WriteInt;
CONST WriteLInt* = Files.WriteLInt;
CONST WriteSet* = Files.WriteSet32;
CONST WriteBool* = Files.WriteBool;
CONST WriteReal* = Files.WriteReal;
CONST WriteLReal* = Files.WriteLReal;
CONST WriteString* = Files.WriteString;
CONST WriteNum* = Files.WriteNum;

CONST Delete* = Files.Delete;
CONST Rename* = Files.Rename;
(*!CONST Copy* = Files.Copy;*)
CONST GetName* = Files.GetName;

END Files.