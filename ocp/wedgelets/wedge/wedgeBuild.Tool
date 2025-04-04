Compiler.Compile 
	wedge/wedgeLinearEq.Mod
	wedge/wedgeQuadraticEq.Mod
	wedge/wedgeGenericEq.Mod
	wedge/wedgeArrays.Mod
	wedge/wedgeTrees.Mod
	wedge/wedgeConstantModels.Mod
	wedge/wedgeLinearModels.Mod
	wedge/wedgeQuadraticModels.Mod
	wedge/wedgeHierarchicModel.Mod
	wedge/wedgeFunctions2d.Mod
	wedge/wedgeGenericModels.Mod
	wedge/wedgeTreePlot.Mod
	wedge/wedgeCommands.Mod
	wedge/antsGammaShooting.Mod
	wedge/wedgeLog.Mod
	wedge/wedgeNumOps.Mod
	wedge/Miniscript.Mod
	wedge/CumulativeMatrices.Mod
	wedge/Wedgelets.Mod
	wedge/Arclets.Mod
~
~

SpotProfiler.Compile *
SpotProfiler.Reset 
SpotProfiler.Show 

remove modules from (RAM) memory
System.Free
wedgeNumOps
wedgeCommands 
wedgeTreePlot
wedgeFunctions2d
wedgeGenericModels
wedgeHierarchicModel
wedgeQuadraticModels
wedgeLinearModels
wedgeConstantModels 
wedgeTrees
wedgeArrays
wedgeGenericEq
wedgeQuadraticEq
wedgeLinearEq
~
System.DeleteFiles 
wedge/wedgeArchive.zip
~~~~~~~~~~~~~~~~~~~

ZipTool.Add wedge/wedgeArchive.zip
wedge/wedgeBuild.Text
wedge/wedgeLinearEq.Mod
wedge/wedgeQuadraticEq.Mod
wedge/wedgeGenericEq.Mod
wedge/wedgeArrays.Mod
wedge/wedgeTrees.Mod
wedge/wedgeConstantModels.Mod
wedge/wedgeLinearModels.Mod
wedge/wedgeQuadraticModels.Mod
wedge/wedgeHierarchicModel.Mod
wedge/wedgeGenericModels.Mod
wedge/wedgeTreePlot.Mod
wedge/wedgeCommands.Mod
wedge/wedgeNumOps.Mod
~

test commands

antsMessages.SetMode verbose ~
antsMessages.SetMode normal ~
antsMessages.SetMode debug  ~

(* load some data, any format, deprecated *)
fofAutomatic.Do 
antsArrayPictures.LoadDialoged testimg ~ 
antsArrayPictures.ToArray  testarray testimg 128 ~
antsArrayPictures.New testimg testarray ~
Voyager.Show testimg as antsPictureViews ~
vyScale.Insert
~


antsArrayObjects.LoadDialogedASCII  name=testarray ~

(* load some data in Ascii PGM format *)
antsArrayObjects.LoadP2  name=testarray    >show    file=^   ~

(*open images in PGM format*)
antsArrayObjects.LoadDialogedP2 testarrayint6 > show ~
wedgeCommands.IntToReal src=testarrayint6 dest=testarray~
wedgeCommands.ComputePSNR src1=testarray5  src2=testarray6~

(*convert original image*)
antsArrayObjects.LoadDialogedP2 testarrayint > show ~
wedgeCommands.IntToReal src= testarrayint dest=testarray~
wedgeCommands.ToAsciiFile src=testarray filename=barbara512.txt~

(*adding noise to original data *)
wedgeNumOps.AddGaussNoise source=testarray dest=noisedarray var=1000~
wedgeCommands.RealToInt src= noisedarray dest=noisedarrayI~
wedgeCommands.Show array=noisedarrayI tree=NIL~
wedgeCommands.ToAsciiFile src=noisedarray filename=barbara512_G100.txt~

wedgeNumOps.AddGaussNoise source=testarray dest=noisedarray var=10~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_G10.txt~

wedgeNumOps.AddGaussNoise source=testarray dest=noisedarray var=100~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_G100.txt~

wedgeNumOps.AddGaussNoise source=testarray dest=noisedarray var=1000~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_G1000.txt~

wedgeNumOps.AddLaplaceNoise source=testarray dest=noisedarray var=10~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_L10.txt~

wedgeNumOps.AddLaplaceNoise source=testarray dest=noisedarray var=100~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_L100.txt~

wedgeNumOps.AddLaplaceNoise source=testarray dest=noisedarray var=1000~
wedgeCommands.ToAsciiFile src=noisedarray filename=circles256_L1000.txt~

(* any format with filename, deprecated *)
fofAutomatic.Do 
antsArrayPictures.Load name=testimg fname="Bilder/cat.gif" ~ 
antsArrayPictures.ToArray  testarray testimg 256 ~
antsArrayPictures.New testimg testarray ~
Voyager.Show testimg as antsPictureViews ~
vyScale.Insert

(* create new tree *)
wedgeCommands.NewTree src=testarray tree=myTree  ~  maxdepth =1 ~
wedgeCommands.NewTree src=testarray tree=myTree  >forceNew ~ 

(* create new constant rect model  *)
wedgeCommands.NewConstRectModel model=rectModel ~
(* plug in  model  *)
wedgeCommands.PlugIn tree=myTree model=rectModel ~

(* create new linear rect model  *)
wedgeCommands.NewLinearRectModel model=rectLinearModel ~
(* plug in model  *)
wedgeCommands.PlugIn tree=myTree model=rectLinearModel ~

(* create new quadratic rect model  *)
wedgeCommands.NewQuadraticRectModel model=rectQuadraticModel ~
(* plug in model  *)
wedgeCommands.PlugIn tree=myTree model=rectQuadraticModel ~

(* create new generic rect model  *)
wedgeCommands.NewGenericRectModel model=rectGenericModel functions= "1" "cos(pi*x)" "sin(pi*x)" "cos(pi*y)" "sin(pi*y)" "sin(pi*x)*sin(pi*y)" "cos(pi*x)*cos(pi*y)"  ~
(* plug in model  *)
wedgeCommands.PlugIn tree=myTree model=rectGenericModel ~


(* plug in constant rect model, newly created if necessary *)
wedgeCommands.PlugInCRect model=rectModel tree=myTree ~

(* plug in linear rect model, newly created if necessary *)
wedgeCommands.PlugInLRect model=rectLinearModel tree=myTree ~

(* create new const wedge model  *)
wedgeCommands.NewConstWedgeModel model=wedgeModel ~
(* set model angle  *)
wedgeCommands.SetConstAngle  model=wedgeModel alpha=45 ~
(* plug in  model *)
wedgeCommands.PlugIn tree=myTree model=wedgeModel ~

(* create new linear wedge model  *)
wedgeCommands.NewLinearWedgeModel model=wedgeLModel ~
(* set model angle  *)
wedgeCommands.SetLinearAngle  model=wedgeLModel alpha=45 ~
(* plug in  model *)
wedgeCommands.PlugIn tree=myTree model=wedgeLModel ~

(* create new quadratic wedge model  *)
wedgeCommands.NewQuadraticWedgeModel model=wedgeQModel ~
(* set model angle  *)
wedgeCommands.SetQuadraticAngle  model=wedgeQModel alpha= 45  ~
(* plug in  model *)
wedgeCommands.PlugIn tree=myTree model=wedgeQModel ~

(* create new generic wedge model  *)
wedgeCommands.NewGenericWedgeModel model=wedgeGModel  functions="1" "x" "y" ~
(* set model angle  *)
wedgeCommands.SetGenericAngle  model=wedgeGModel alpha= 45  ~
(* plug in  model *)
wedgeCommands.PlugIn tree=myTree model=wedgeGModel ~

(* create new generic rect model from array *)
wedgeCommands.NewModelTest model=rectGenericModelfromarray  tree=myTree  nbregions=3  functions="1" "x" "y"~
(* plug in model  *)
wedgeCommands.PlugIn tree=myTree model=rectGenericModelfromarray ~


wedgeCommands.PlugInCWedge  tree=myTree model=wedgeModel  >adaptive numofangles=180 offset=4 ~
(* plug in wedge model with different angles at once, newly created if necessary *)
wedgeCommands.PlugInCWedge  tree=myTree model=wedgeModel  angles= 22.5 45 70 90 135 ~
wedgeCommands.PlugInCWedge  tree=myTree model=wedgeModel  >steps from= 0 to=180 by=10 ~

(* plug in linear wedge model with different angles at once, newly created if necessary *)
wedgeCommands.PlugInLWedge  tree=myTree model=wedgeLModel  angles= 22.5 45 70 90 135 ~
wedgeCommands.PlugInLWedge  tree=myTree model=wedgeLModel  >steps from= 0 to=180 by=10 ~

wedgeCommands.PlugInQWedge  tree=myTree model=wedgeQModel  >adaptive numofangles=10 offset = 4 ~

(* plug in quadratic wedge model with different angles at once, newly created if necessary *)
wedgeCommands.PlugInQWedge  tree=myTree model=wedgeQModel  angles= 45 90 135 180 20  ~
wedgeCommands.PlugInQWedge  tree=myTree model=wedgeQModel  >steps from= 0 to=179 by=18 ~

(* plug in generic wedge model with different angles at once, newly created if necessary *)
wedgeCommands.PlugInGWedge  tree=myTree model=wedgeGModel0 functions= "1" "x" "y" angles= 0 45 90 135  ~

wedgeCommands.PlugInGWedge  tree=myTree model=wedgeGModel   functions= "1" "x" "y"  >steps from= 0 to=180 by=10 ~


(* remove model from tree *)
wedgeCommands.Remove tree=myTree model=rectModel ~
wedgeCommands.RemoveAll tree=myTree ~
wedgeCommands.Remove tree=myTree model=wedgeModel ~
wedgeCommands.Remove tree=myTree model=wedgeLModel ~
wedgeCommands.Remove tree=myTree model=wedgeQModel ~


(* global minimization *) 
wedgeCommands.Minimize tree=myTree gamma= 10  ~
(* result to array *)
wedgeCommands.ToArray tree=myTree destI=resultI ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.RealToInt src=resultR dest=resultI ~
wedgeCommands.PSNR src1

(* display result *)
wedgeCommands.Show array=resultI tree=NIL~
wedgeCommands.Show array=NIL tree=myTree  ~
Voyager.Show myTree as wedgeTreePlot ~ (* equivalent to previous command *)
wedgeCommands.Show array=resultI tree=myTree  ~




Gadgets.Insert ScrollbarsR.New  ~


(*  more information about the created tree *)
fofAutomatic.Do 
antsMessages.SetPrio ToCaret
wedgeCommands.Report tree=myTree ~
antsMessages.SetPrio ToLog 
~


(*! think about ideas to prevent from huge structures to be cleaned by the garbage collector, flatten trees ? *) 
wedgeCommands.PSNR tree=myTree from=0 to= 100 by = 1 PSNR=PSNRVec  penalty=penaltyVec ~

Voyager.Show PSNRVec as LinePlot ~
Voyager.Show penaltyVec as LinePlot ~
Voyager.Show PSNRVec penaltyVec as Charts ~


vyScale.Insert 
Voyager.Show msevec   sizevec    as Charts~
Voyager.Show PSNRvec sizevec    as Charts~
vyScale.Insert~
~

System.DeleteFiles testfile ~

Verrauschen des Bildes  - gaussches Rauschen:
wedgeNumOps.AddGaussNoise src=testarray dest=testarray var=1000 ~
wedgeNumOps.AddUniformNoise src=testarray dest=testarray var=1000 ~
wedgeNumOps.AddExpNoise src=testarray dest=testarray var=1000 ~
wedgeNumOps.AddLaplaceNoise src=testarray dest=testarray var=1000 ~



(* Plot der Funktion, ihrer Ableitungen und BErechnung des Minimums *)
fofAutomatic.Do 
wedgeNumOps.NewVec gammavec ~
wedgeNumOps.NewVec piecesvec ~
wedgeNumOps.LogGammaVectors tree=myTree from=-5  to=5 by=0.05 gamma=gammavec pieces=piecesvec ~
wedgeNumOps.Log10 piecesvec ~
wedgeNumOps.Log10 gammavec~
wedgeNumOps.Copy from=gammavec to= gammavecfd ~
wedgeNumOps.Copy from=piecesvec to=piecesvecfd ~
wedgeNumOps.Copy from=gammavec to= gammavecsd ~
wedgeNumOps.Copy from=piecesvec to=piecesvecsd ~
wedgeNumOps.FirstDerivate fdx=gammavecfd fdy=piecesvecfd ~
wedgeNumOps.Copy from=gammavecfd to= minx ~
wedgeNumOps.Copy from=piecesvecfd to= miny~
wedgeNumOps.SecondDerivate sdx= gammavecsd sdy=piecesvecsd ~
wedgeNumOps.ShowVec vecx=gammavecfd vecy=piecesvecfd  port=View1>forcenew ~
vyGraphicCtl.SetWidth 1 ~
vyGraphicCtl.SetColor FORECO 8 ~
vyGraphicCtl.SetBackColor 0 
vyScale.Insert 
wedgeNumOps.ShowVec vecx=gammavecsd vecy=piecesvecsd  port=View2>forcenew ~
vyGraphicCtl.SetWidth 1 ~
vyGraphicCtl.SetColor FORECO 8 ~
vyGraphicCtl.SetBackColor 0 
vyScale.Insert 
wedgeNumOps.ShowVec vecx=gammavec vecy=piecesvec  port=View3 >forcenew ~
vyGraphicCtl.SetWidth 1 ~
vyGraphicCtl.SetColor FORECO 8 ~
vyGraphicCtl.SetBackColor 0 ~
vyScale.Insert 
wedgeNumOps.MinimaLoc vecx=minx vecy=miny fdx= gammavecsd fdy=piecesvecsd step=0.02
~
