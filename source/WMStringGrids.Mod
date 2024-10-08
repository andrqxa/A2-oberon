MODULE WMStringGrids; (** AUTHOR "TF"; PURPOSE "String grid  component"; *)

IMPORT
	Objects, Strings, XML, WMComponents, WMGraphics, WMGraphicUtilities,
	WMProperties, WMEvents, WMRectangles, WMGrids;

CONST
	(* Cell.flags *)
	UsePerCellColors = 0;
	UseInternalBuffer = 1;

TYPE
	String = Strings.String;

	Cell* = OBJECT
	VAR
		caption : String;
		color, textColor : WMGraphics.Color;
		align: INTEGER;
		img : WMGraphics.Image;
		data : ANY;
		flags : SET;

		PROCEDURE &Init;
		BEGIN
			caption := NIL;
			color := 0; textColor := 0; align := 0;
			img := NIL;
			data := NIL;
			flags := {};
		END Init;

	END Cell;

	CellArray = POINTER TO ARRAY OF Cell;

	Row = POINTER TO RECORD
		cells : CellArray;
	END;

	RowArray = POINTER TO ARRAY OF Row;

TYPE

	StringGridModel* = OBJECT
	VAR
		lockedBy : ANY;
		lockLevel : SIZE;
		viewChanged : BOOLEAN;
		onChanged* : WMEvents.EventSource; (** does not hold the lock, if called *)
		rows : RowArray;
		nofRows, nofCols : SIZE;

		PROCEDURE &Init*;
		BEGIN
			NEW(onChanged, SELF, Strings.NewString("StringGridModelChanged"), NIL, NIL);
			NEW(rows, 4);
			lockLevel :=0;
		END Init;

		(** acquire a read/write lock on the object *)
		PROCEDURE Acquire*;
		VAR me : ANY;
		BEGIN {EXCLUSIVE}
			me := Objects.ActiveObject();
			IF lockedBy = me THEN
				ASSERT(lockLevel # -1);	(* overflow *)
				INC(lockLevel)
			ELSE
				AWAIT(lockedBy = NIL); viewChanged := FALSE;
				lockedBy := me; lockLevel := 1
			END
		END Acquire;

		(** release the read/write lock on the object *)
		PROCEDURE Release*;
		VAR hasChanged : BOOLEAN;
		BEGIN
			BEGIN {EXCLUSIVE}
				ASSERT(lockedBy = Objects.ActiveObject(), 3000);
				hasChanged := FALSE;
				DEC(lockLevel);
				IF lockLevel = 0 THEN lockedBy := NIL; hasChanged := viewChanged END
			END;
			IF hasChanged THEN onChanged.Call(NIL) END
		END Release;

		PROCEDURE AdjustRows(newSize : SIZE);
		VAR i : SIZE; newRows : RowArray;
		BEGIN
			NEW(newRows, newSize);
			FOR i := 0 TO MIN(nofRows, newSize) - 1 DO
				newRows[i] := rows[i]
			END;
			FOR i := MIN(nofRows, newSize)  TO newSize - 1 DO
				NEW(newRows[i]);
				AdjustRow(newRows[i])
			END;
			rows := newRows
		END AdjustRows;

		PROCEDURE AdjustRow(row : Row);
		VAR i : SIZE; newCells : CellArray;
		BEGIN
			IF row.cells = NIL THEN NEW(row.cells, nofCols) END;
			IF LEN(row.cells) # nofCols THEN
				NEW(newCells, nofCols);
				FOR i := 0 TO MIN(nofCols, LEN(row.cells)) - 1 DO
					newCells[i] := row.cells[i]
				END;
				row.cells := newCells
			END
		END AdjustRow;

		PROCEDURE SetNofRows*(newNofRows : SIZE);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (newNofRows > nofRows) OR (newNofRows < nofRows DIV 2)  THEN AdjustRows(newNofRows) END;
			nofRows := newNofRows;
			viewChanged := TRUE
		END SetNofRows;

		PROCEDURE SetNofCols*(newNofCols : SIZE);
		VAR i : SIZE;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			nofCols := newNofCols;
			FOR i := 0 TO nofRows - 1 DO AdjustRow(rows[i]) END;
			viewChanged := TRUE
		END SetNofCols;

		PROCEDURE GetNofRows*() : SIZE;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			RETURN nofRows
		END GetNofRows;

		PROCEDURE GetNofCols*() : SIZE;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			RETURN nofCols
		END GetNofCols;

		PROCEDURE SetCellText*(col, row : SIZE; caption : String);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				EXCL(rows[row].cells[col].flags, UseInternalBuffer);
				IF rows[row].cells[col].caption # caption THEN
					rows[row].cells[col].caption := caption;
					viewChanged := TRUE
				END
			END
		END SetCellText;

		PROCEDURE GetCellText*(col, row : SIZE ) : String;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN RETURN NIL END;
				RETURN rows[row].cells[col].caption
			ELSE RETURN NIL
			END
		END GetCellText;

		PROCEDURE SetCellTextAOC*(col, row, minBufferSize : SIZE; CONST caption : ARRAY OF CHAR);
		VAR cell : Cell; length : SIZE;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				length := MAX(minBufferSize, Strings.Length(caption) + 1); (* 0X *)
				cell := rows[row].cells[col];
				IF (cell.caption = NIL) OR ~(UseInternalBuffer IN cell.flags) OR (LEN(cell.caption) < length) THEN
					NEW(cell.caption, length);
					INCL(cell.flags, UseInternalBuffer);
				END;
				IF (cell.caption^ # caption) THEN
					COPY(caption, rows[row].cells[col].caption^);
					viewChanged := TRUE
				END
			END
		END SetCellTextAOC;

		PROCEDURE GetCellTextAOC*(col, row : SIZE; VAR caption : ARRAY OF CHAR);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] # NIL THEN
					COPY(rows[row].cells[col].caption^, caption);
				ELSE
					caption := "";
				END;
			ELSE
				caption := "";
			END
		END GetCellTextAOC;

		PROCEDURE SetCellColors*(col, row : SIZE; color, textColor : WMGraphics.Color);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				INCL(rows[row].cells[col].flags, UsePerCellColors);
				IF rows[row].cells[col].color # color THEN
					rows[row].cells[col].color := color;
					viewChanged := TRUE;
				END;
				IF rows[row].cells[col].textColor # textColor THEN
					rows[row].cells[col].textColor := textColor;
					viewChanged := TRUE;
				END;
			END;
		END SetCellColors;

		PROCEDURE GetCellColors*(col, row : SIZE; VAR color, textColor : WMGraphics.Color; VAR valid : BOOLEAN);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			valid := FALSE;
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF (rows[row].cells[col] # NIL) & (UsePerCellColors IN rows[row].cells[col].flags) THEN
					valid := TRUE;
					color := rows[row].cells[col].color;
					textColor := rows[row].cells[col].textColor;
				END;
			END;
		END GetCellColors;

		PROCEDURE SetCellData*(col, row : SIZE; data : ANY);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				IF rows[row].cells[col].data # data THEN
					rows[row].cells[col].data:= data;
					viewChanged := TRUE
				END
			END
		END SetCellData;

		PROCEDURE GetCellData*(col, row : SIZE) : ANY;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN RETURN NIL END;
				RETURN rows[row].cells[col].data
			ELSE RETURN NIL
			END
		END GetCellData;

		PROCEDURE SetCellImage*(col, row : SIZE; img : WMGraphics.Image);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				IF rows[row].cells[col].img # img THEN
					rows[row].cells[col].img := img;
					viewChanged := TRUE
				END
			END
		END SetCellImage;

		PROCEDURE GetCellImage*(col, row : SIZE) : WMGraphics.Image;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN RETURN NIL END;
				RETURN rows[row].cells[col].img
			ELSE RETURN NIL
			END
		END GetCellImage;

		PROCEDURE SetTextAlign*(col, row : SIZE; align : INTEGER);
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN NEW(rows[row].cells[col]) END;
				IF rows[row].cells[col].align # align THEN
					rows[row].cells[col].align:= align;
					viewChanged := TRUE
				END
			END
		END SetTextAlign;

		PROCEDURE GetTextAlign*(col, row : SIZE) : INTEGER;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (col >= 0) & (row >= 0) & (col < nofCols) & (row < nofRows) THEN
				IF rows[row].cells[col] = NIL THEN RETURN 0 END;
				RETURN rows[row].cells[col].align
			ELSE RETURN 0
			END
		END GetTextAlign;

		PROCEDURE DeleteRow*(rowNo : SIZE; viewChanged : BOOLEAN);
		VAR i : SIZE;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (rowNo >=  0) & (rowNo < nofRows) THEN
				FOR i := rowNo TO nofRows - 2 DO
					rows[i] := rows[i + 1]
				END;
				DEC(nofRows);
				SELF.viewChanged := viewChanged
			END
		END DeleteRow;

		PROCEDURE InsertEmptyRow*(atRowNo : SIZE);
		VAR i : SIZE;
			newRows : RowArray;
		BEGIN
			ASSERT(Objects.ActiveObject() = lockedBy, 3000);
			IF (atRowNo >= 0) & (atRowNo <= nofRows) THEN
				NEW(newRows, nofRows + 1);
				FOR i := 0 TO atRowNo - 1 DO
					newRows[i] := rows[i]
				END;
				NEW(newRows[atRowNo]);
				AdjustRow(newRows[atRowNo]);
				FOR i := atRowNo + 1 TO nofRows DO
					newRows[i] := rows[i - 1]
				END
			END;
			INC(nofRows);
			rows := newRows;
			viewChanged := TRUE
		END InsertEmptyRow;

	END StringGridModel;

TYPE

	StringGrid* = OBJECT(WMGrids.GenericGrid)
	VAR
		model- : StringGridModel;
		cellColor, hoverColor, selectedColor, fixedColor, textHoverColor, textColor, textSelectedColor : WMGraphics.Color;
		clCell-, clFixed-, clHover-, clSelected-, clTextDefault-, clTextHover-, clTextSelected- : WMProperties.ColorProperty;
		showImgOnlyCells-: WMProperties.BooleanProperty; 
		
		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrStringGrid);
			SetGenerator("WMStringGrids.GenStringGrid");
			NEW(clCell, PrototypeTclCell, NIL, NIL); properties.Add(clCell);
			NEW(clHover, PrototypeTclHover, NIL, NIL); properties.Add(clHover);
			NEW(clSelected, PrototypeTclSelected, NIL, NIL); properties.Add(clSelected);
			NEW(clFixed, PrototypeTclFixed, NIL, NIL); properties.Add(clFixed);

			NEW(clTextDefault, PrototypeTclTextDefault, NIL, NIL); properties.Add(clTextDefault);
			NEW(clTextHover, PrototypeTclTextHover, NIL, NIL); properties.Add(clTextHover);
			NEW(clTextSelected, PrototypeTclTextSelected,  NIL, NIL); properties.Add(clTextSelected);
			NEW(showImgOnlyCells, PrototypeShowImgOnlyCells, NIL, NIL); properties.Add(showImgOnlyCells);
		(*	NEW(fontHeight, PrototypeTfontHeight, NIL, NIL); properties.Add(fontHeight);	*)
			takesFocus.Set(TRUE);
			NEW(model);
			model.onChanged.Add(ModelChanged);
			ModelChanged(NIL,NIL);
		END Init;

		PROCEDURE ModelChanged(sender, data : ANY);
		BEGIN
			Acquire;
			nofCols.Set(model.nofCols);
			nofRows.Set(model.nofRows);
			SetDrawCellProc(DrawCell);
			Invalidate;
			Release
		END ModelChanged;

		PROCEDURE DrawBackground*(canvas : WMGraphics.Canvas);
		BEGIN
			cellColor := clCell.Get();
			hoverColor := clHover.Get();
			selectedColor := clSelected.Get();
			fixedColor := clFixed.Get();
			textColor := clTextDefault.Get();
			textHoverColor := clTextHover.Get();
			textSelectedColor := clTextSelected.Get();
			model.Acquire;
			DrawBackground^(canvas);
			model.Release
		END DrawBackground;

		PROCEDURE GetCellData*(col, row : SIZE) : ANY;
		VAR data : ANY;
		BEGIN
			model.Acquire;
			data := model.GetCellData(col, row);
			model.Release;
			RETURN data
		END GetCellData;

(*		PROCEDURE CellClicked*(col, row : SIZE); (** PROTECTED *)
		BEGIN
			model.Acquire;
			data := model.GetCellData(col, row);
			model.Release;
			CellClicked^(col, row);
	(*		onClick.Call(data);
			IF wasSelected  & onClickSelected.HasListeners() THEN
				onClickSelected.Call(data)
			END; *)
		END CellClicked; *)

		PROCEDURE DrawCell(canvas : WMGraphics.Canvas; w, h : SIZE; state : SET; x, y : SIZE);
		VAR
			s : String; font : WMGraphics.Font; left: SIZE; c, tc: WMGraphics.Color; img : WMGraphics.Image; dispW, dispH: SIZE;
			valid : BOOLEAN;
		BEGIN
			s := model.GetCellText(x, y);

			model.GetCellColors(x, y, c, tc, valid);
			IF ~valid THEN
				c := cellColor;
				tc := textColor;
			END;

			IF WMGrids.CellFixed IN state THEN
				c := fixedColor;
				IF WMGrids.CellSelected IN state THEN
					c := WMGraphicUtilities.InterpolateColorLinear(c, selectedColor, 128)
				ELSIF  WMGrids.CellHighlighted IN state THEN
					c := WMGraphicUtilities.InterpolateColorLinear(c, hoverColor, 128)
				END;
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), c, WMGraphics.ModeCopy)
			ELSIF WMGrids.CellSelected IN state THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), selectedColor, WMGraphics.ModeSrcOverDst);
				tc := textSelectedColor
			ELSIF WMGrids.CellHighlighted IN state THEN
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), hoverColor, WMGraphics.ModeSrcOverDst);
				tc := textHoverColor
			ELSE
				canvas.Fill(WMRectangles.MakeRect(0, 0, w, h), c, WMGraphics.ModeSrcOverDst)
			END;

			font := GetFont();
			canvas.SetColor(tc);
			left := 1; img := model.GetCellImage(x, y);
			IF img # NIL THEN INC(left, img.width + 1) END;

			IF (s # NIL) OR showImgOnlyCells.Get() THEN
				IF img # NIL THEN
					dispW := img.width;
					dispH := img.height;
					IF dispW > w-2 THEN dispW := w-2 END;
					IF dispH > h-2 THEN dispH := h-2 END;
					IF (dispW # img.width) OR (dispH # img.height) THEN
						canvas.ScaleImage(img, WMRectangles.MakeRect(0, 0, img.width, img.height),	WMRectangles.MakeRect(1, 1, dispW, dispH), WMGraphics.ModeSrcOverDst, 10);
					ELSE
						canvas.DrawImage(1, 1, img, WMGraphics.ModeSrcOverDst);
					END
				END;
				IF s#NIL THEN
					WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(left, 1, w - 2, h - 2), FALSE,
						model.GetTextAlign(x, y), WMGraphics.AlignCenter, s^)
				END;
			END;
			IF WMGrids.CellSelected IN state THEN
				WMGraphicUtilities.ExtRectGlassShade(canvas, WMRectangles.MakeRect(0, 0, w, h), {1, 3}, 5, FALSE);
			END
			(* IF s # NIL THEN canvas.DrawString(0, h - font.descent, s^) END *)
		END DrawCell;

	END StringGrid;

VAR
	 PrototypeTclCell*, PrototypeTclHover*, PrototypeTclSelected*, PrototypeTclTextDefault*,
	 PrototypeTclTextHover*, PrototypeTclTextSelected*, PrototypeTclFixed* : WMProperties.ColorProperty;
	 PrototypeTfontHeight* : WMProperties.Int32Property;
	 PrototypeShowImgOnlyCells*: WMProperties.BooleanProperty;
	 StrStringGrid : Strings.String;

PROCEDURE GenStringGrid*() : XML.Element;
VAR stringGrid : StringGrid;
BEGIN
	NEW(stringGrid); RETURN stringGrid;
END GenStringGrid;

PROCEDURE InitStrings;
BEGIN
	StrStringGrid := Strings.NewString("StringGrid");
END InitStrings;

PROCEDURE InitPrototypes;
VAR plStringGrid : WMProperties.PropertyList;
BEGIN
	NEW(plStringGrid);
	NEW(PrototypeTclCell, NIL, Strings.NewString("ClCell"), Strings.NewString("color of the cell"));
	plStringGrid.Add(PrototypeTclCell);
	NEW(PrototypeTclFixed, NIL, Strings.NewString("ClFixed"), Strings.NewString("color of a fixed cell"));
	plStringGrid.Add(PrototypeTclFixed);
	NEW(PrototypeTclHover, NIL, Strings.NewString("ClHover"), Strings.NewString("color of the grid item, if the mouse is over it"));
	plStringGrid.Add(PrototypeTclHover);
	NEW(PrototypeTclSelected, NIL, Strings.NewString("ClSelected"), Strings.NewString("color of the the grid item, if it is selected"));
	plStringGrid.Add(PrototypeTclSelected);
	NEW(PrototypeTclTextDefault, NIL, Strings.NewString("ClTextDefault"), Strings.NewString("default text color of the grid item"));
	plStringGrid.Add(PrototypeTclTextDefault);
	NEW(PrototypeTclTextHover, NIL, Strings.NewString("ClTextHover"), Strings.NewString("text color of the grid item, if the mouse is over it"));
	plStringGrid.Add(PrototypeTclTextHover);
	NEW(PrototypeTclTextSelected, NIL, Strings.NewString("ClTextSelected"), Strings.NewString("text color of the grid item, when selected"));
	plStringGrid.Add(PrototypeTclTextSelected);
	NEW(PrototypeTfontHeight, NIL, Strings.NewString("FontHeight"), Strings.NewString("height of the grid item text"));
	plStringGrid.Add(PrototypeTfontHeight);
	NEW(PrototypeShowImgOnlyCells, NIL, Strings.NewString("showImageOnlyCells"), Strings.NewString("show cells that have no text, only img"));
	plStringGrid.Add(PrototypeShowImgOnlyCells);

	PrototypeTclCell.Set(SIGNED32(0FFFFFFFFH));
	PrototypeTclFixed.Set(SIGNED32(0CCCCCCFFH));
	PrototypeTclHover.Set(SIGNED32(0FFFF00FFH));
	PrototypeTclSelected.Set(00000FFFFH);
	PrototypeTclTextDefault.Set(0000000FFH);
	PrototypeTclTextHover.Set(00000FFFFH);
	PrototypeTclTextSelected.Set(SIGNED32(0FFFFFFFFH));

	PrototypeTfontHeight.Set(12);
	PrototypeShowImgOnlyCells.Set(FALSE);
	WMComponents.propertyListList.Add("StringGrid", plStringGrid);
	WMComponents.propertyListList.UpdateStyle;
END InitPrototypes;

BEGIN
	InitStrings;
	InitPrototypes;
END WMStringGrids.

MODULE ShowGrid; (** AUTHOR ""; PURPOSE ""; *)
IMPORT WMGrids, WMStringGrids, WMComponents, WMStandardComponents, WMGraphics, WMWindowManager;
VAR g:WMStringGrids.StringGrid;

PROCEDURE Cast(CONST a:ARRAY[*] OF SIZE):POINTER TO ARRAY OF SIZE;
VAR i:SIZE;
BEGIN
	NEW(RESULT,LEN(a,0));
	FOR i:=0 TO LEN(a,0)-1 DO RESULT[i]:=a[i]
	END;
	RETURN RESULT
END Cast;


PROCEDURE Do*;
VAR 
	p:WMStandardComponents.Panel; 
	img: WMGraphics.Image;
	win:WMComponents.FormWindow;
	rowSp,colSp: WMGrids.Spacings;
BEGIN
	g:=WMStringGrids.GenStringGrid()(WMStringGrids.StringGrid);
	rowSp:=Cast([20,20,20,20,20,20,20,20,20,20]); g.SetRowSpacings(rowSp);
	colSp:=Cast([20,20,20,20,20,20,20,20,20,20]); g.SetColSpacings(colSp);
	g.model.Acquire;
	g.alignment.Set(WMComponents.AlignClient);
	g.model.SetNofRows(10);
	g.model.SetNofCols(3);
	p:=WMStandardComponents.GenPanel()(WMStandardComponents.Panel); p.fillColor.Set(WMGraphics.Color(0FF0000FFH));
	g.model.SetCellData(0,0,p);
	img:=WMGraphics.LoadImage("Yellow_Duck.jpg",FALSE);
	g.model.SetCellTextAOC(0,1,12,"yellow duck");
	rowSp[1]:=100; g.SetRowSpacings(rowSp);
	colSp[0]:=100; g.SetColSpacings(colSp);
	g.model.SetCellImage(0,1,img);
	p:=WMStandardComponents.GenPanel()(WMStandardComponents.Panel); p.fillColor.Set(000FF00FFH);
	g.model.SetCellData(1,0,p);
	p:=WMStandardComponents.GenPanel()(WMStandardComponents.Panel); p.fillColor.Set(000FFFFH);
	g.model.SetCellData(2,1,p);
	NEW(win,200,400, FALSE); win.SetContent(g);
	g.model.Release;
	WMWindowManager.DefaultAddWindow(win);
END Do;

END ShowGrid.

ShowGrid.Do ~

System.FreeDownTo WMInspectionComponents WMStringGrids ShowGrid~

ComponentViewer.Open WMStringGrids.GenStringGrid ~

