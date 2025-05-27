MODULE StatisticsRobustRegression; (** AUTHOR "Patrick Hunziker 2012"; PURPOSE "Robust Regression Models"; *)
(*! work needed: implement univariate and multivariate Theil-Sen here, including Theil-Sen for streams. (references given below)
	linear methods to be removed *)

	(*! important source of inspiration for robust statistics:  http://stat.ethz.ch/people/maechler/robustness *)


(*mathematical limitations for linear regression are summarized in
http://en.wikipedia.org/wiki/Linear_regression_model
and can lead to failure of the algorithm/solvers.
If the used QR solver (current standard in MatrixLeastSquares) fails in an underdetermined system,
a SVD based least squares solver for least squares computation (in all types off systems) will help,
or a Krylov based solver may help.
*)

IMPORT MatrixBase, MatrixLeastSquares, StatisticsFunctions, Util:=MatrixUtilities, Streams, Random, KernelLog, StatisticsBase,
	StatisticsLinearRegression, MathL, Reals, MatrixPrincipalComponents, MatrixStandardSolvers;

(* http://en.wikipedia.org/wiki/Linear_regression *)
(**

elementwise:
	y1 = b1 x11+b2 x12 +b3 x13 .. + e1
	y2 = b2 x21 ...

Usually a constant is included as one of the regressors.
For example we can take xi1 = 1 for i = 1, ..., n.
The corresponding element of X is called the intercept.

vector form:
 y= Xb + e  ; with y,b,e: vector; X: matrix (in the simplest case, only  one column)

least squares formulation
 X`X b = X` y

 or
 b= Invert(X`X) * X`y
 *)

TYPE Matrix*=MatrixBase.Matrix;
	Vector*=MatrixBase.Vector;
	Scalar*=MatrixBase.Datatype;

VAR w: Streams.Writer;
	eps0, eps: Scalar;
	random:Random.Generator;
(**
y = Xb + e

y: Observed response variables, vector
x: regressors = input variables, one row for each response element, making up the design matrix X;
b: regression coefficient vector, to be determined
e: error term
usually, a constant is included in the regressors X, (e.g. all xi1 := 1), and the resulting b is called intercept.
See example in Test() below.
*)

TYPE Regression*= OBJECT (*! work needed: implement univariate and multivariate Theil-Sen here*)
		VAR
			X: Matrix;
			b-, e-, yestimate-: Vector; (* regression coefficients and residual  for regression and simple regression*)
			B-,U-: Matrix; (* regression coefficients and residuals for GLM *)
			R2-,	(* see http://en.wikipedia.org/wiki/Coefficient_of_determination *)
			R2adj-, (* adjusted R2 [korrigiertes Bestimmtheitsmass, adjusts for number o regressors, http://en.wikipedia.org/wiki/Coefficient_of_determination#Adjusted_R2
						suited to explore if a model with a restricted or a nonrestricted number of regressors is prefereable: the best model has the highest R2corr *)
			RSS-, (* residual sum of squares = sum of squared residuals *)
			F-, p-, ymean-: Scalar;

			ls: MatrixLeastSquares.LeastSquares;

			isGLM:BOOLEAN;
			nvar, nsamp: SIZE;

		PROCEDURE &Init*(CONST X: Matrix; intercept: BOOLEAN);
		BEGIN
			IF LEN(X,0)>0 THEN
				nvar:=LEN(X,1);
				nsamp:=LEN(X,0);
				IF intercept THEN	NEW(SELF.X, nsamp, nvar+1); SELF.X[..,0]:=1; SELF.X[..,1..]:=X;
				ELSE SELF.X:=X
				END;
				NEW(ls, SELF.X);
			ELSE (* needs later call of Init() or InitSimple() *)
			END;
		END Init;

		PROCEDURE InitSimple*(CONST x:Vector; intercept:BOOLEAN);
		BEGIN
			(*
			ASSERT(LEN(x,0)>0);
			nvar:=1;
			nsamp:=LEN(x,0);
			IF intercept THEN NEW (X, nsamp, 2); X[..,0]:=1; X[..,1]:=x;
			ELSE NEW(X,nsamp, 1); X[..,0]:=x;
			END;
			NEW(ls, X);
			*)
		END InitSimple;

		PROCEDURE Solve*(CONST y: Vector):Vector; (* yields b *)
		BEGIN
			(*
			isGLM:=FALSE;
			b:=ls.Solve(y);
			yestimate:=X*b;
			ymean:=SUM(y)/LEN(y,0);
				(* coefficient of determination *)
			e:= y- yestimate;
			RSS:=e+*e;
			R2:= 1-(RSS / ((y-ymean)+*(y-ymean)));
			IF nsamp#(nvar+1) THEN (*no division by zero*)
				R2adj:=1-(1-R2)*((nsamp-1)/(nsamp-nvar-1));
				F:= (R2/(nvar+1)) / ((1-R2)/(nsamp-nvar-1));
				p := StatisticsFunctions.PSnedecor(nsamp,nvar,F); (* due to a problem in StatisticsFunctions.Mod, p works only for even degrees of freedom *)
			END;
			RETURN b
			*)
		END Solve;

		PROCEDURE SolveGLM*(CONST Y:Matrix): Matrix; (* yields B *)
		VAR i:SIGNED32; y, b,e: Vector;
		BEGIN
			(*
			isGLM:=TRUE;
			NEW(B, LEN(X,1), LEN(Y,1));
			NEW(U, LEN(Y,0), LEN(Y,1));
			FOR i:=0 TO LEN(Y,1)-1 DO (* can be optimized *)
				y:=Y[..,i];
				b:=ls.Solve(y);
				e:= y- X*b;
				B[..,i]:=b;
				U[..,i]:=e;
			END;
			RETURN B
			*)
			(*! to do: compute regression coefficient R2, F-statistics, and p value*)
		END SolveGLM;
	END Regression;

(* Theil-Sen Estimator for data streams: http://dx.doi.org/10.1145/1240233.1240239 *)
TYPE Stream_TheilSenEstimator*=OBJECT
	END Stream_TheilSenEstimator;

(* Multivariate Theil-Sen Estimator:
multivariate median:
http://papers.ssrn.com/sol3/Delivery.cfm/SSRN_ID1690502_code847251.pdf?abstractid=1690502&mirid=3

multivariate theil-sen implementations:
http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.78.7797
http://home.olemiss.edu/~xdang/papers/MTSE.pdf
*)
TYPE Multivariate_TheilSenEstimator*=OBJECT
END Multivariate_TheilSenEstimator;

PROCEDURE LinearRegression*(CONST X: Matrix; CONST y: Vector; VAR b, e: Vector);
VAR ls: MatrixLeastSquares.LeastSquares;
BEGIN
	NEW(ls, X);
	b:=ls.Solve(y);
	e:= y- X*b;
END LinearRegression;

(* no intercept, assumption is that regression line goes through origin *)
PROCEDURE SimpleRegressionNoIntercept*(CONST x: Vector; CONST y: Vector; VAR b: Scalar; VAR e: Vector);
VAR X: Matrix; B: Vector;
BEGIN
	(*can be simplified*)
	NEW(X, LEN(x,0), 1);
	X[..,0]:=x;
	LinearRegression(X,y,B,e);
	b:=B[0];
END SimpleRegressionNoIntercept;

PROCEDURE SimpleRegression*(CONST x: Vector; CONST y: Vector; VAR b, intercept: Scalar; VAR e: Vector);
VAR X: Matrix; B: Vector;
BEGIN
	(*can be simplified*)
	NEW(X, LEN(x,0), 2);
	X[..,0]:=1;
	X[..,1]:=x;
	LinearRegression(X,y,B,e);
	intercept:=B[0];
	b:=B[1];
END SimpleRegression;

(**
The general linear model (GLM) is a statistical linear model. It may be written as
    Y = XB + U
where Y is a matrix with series of multivariate measurements,
X is a matrix that might be a design matrix,
B is a matrix containing parameters that are usually to be estimated and
U is a matrix containing errors or noise.

The general linear model incorporates a number of different statistical models:
ANOVA, ANCOVA, MANOVA, MANCOVA, ordinary linear regression, t-test and F-test.
The general linear model is a generalization of multiple linear regression model to
the case of more than one dependent variable.

see http://en.wikipedia.org/wiki/General_linear_model
*)

PROCEDURE GeneralLinearModel*(CONST X: Matrix; CONST Y: Matrix; VAR B, U: Matrix); (** not exhaustively tested *)
	VAR ls: MatrixLeastSquares.LeastSquares;
		y, b,e: Vector; i,j,j0:SIZE;
BEGIN
	NEW(ls, X);
	NEW(B, LEN(X,1), LEN(Y,1));
	NEW(U, LEN(Y,0), LEN(Y,1));
	FOR i:=0 TO LEN(Y,1)-1 DO
		y:=Y[..,i];
		b:=ls.Solve(y);
		e:= y- X*b;
		B[..,i]:=b;
		U[..,i]:=e;
	END;
END GeneralLinearModel;

(*
The Theil-Sen estimator is a simple robust estimation technique that determine the slope of a dataset
as the median of the slopes of the lines through pairs of sample points.
It has similar statistical efficiency properties to simple regression but is much less sensitive to outliers.
Note that at current, this implementation can limit the number of pairs for efficiency reasons, while it may also consider all pairs, thus being therefore O(N*N) with added sorting.
see http://en.wikipedia.org/wiki/Theil%E2%80%93Sen_estimator for  details
**)
PROCEDURE TheilSenEstimator*(CONST x: Vector; CONST y: Vector; VAR b, intercept: Scalar; VAR e: Vector; nPairs:=200:SIZE);(*!tbd: reuse slopes*)
VAR slopes: Vector; i,j,j0,len:SIZE; dx, dy, val: Scalar;
BEGIN
	(*choose sample pairs*)
	len:=nPairs;
	NEW(slopes, len);
	i:=0; j:=0;
	WHILE i<len DO
		j0:=j;
		j:=random.Dice(SIGNED32(LEN(x,0)));
		(*? possible improvement: also randomize i, or choose i with large dx *) 
		dx:=x[j]-x[j0];
		dy:=y[j]-y[j0];
		IF dx#0 THEN val:=dy/dx; slopes[i]:=val; INC(i) END;
	END;
	b := StatisticsBase.DestructiveMedian(slopes);(*choose median slope *)
	(* StatisticsBase.QSort(slopes); b:=slopes[nPairs DIV 2]; *)(*choose slope at fraction[0 <..< nPairs] *)
	(*	StatisticsBase.KSmallest(slopes,nPairs DIV 2)	*)
	e:=y-b*x;
	intercept:=SUM(e)/LEN(e,0);
	e:=e-intercept;
	(*optional: estimation of 95% confidence interval, based on observation of 600 pairs is sufficient according to literature*)
END TheilSenEstimator;

(* experiment: for each predictor dimension, a TheilSen Estimate is done.
	Multidimensional regression is assumed to be a composite of those partial regressions .
	b[0] is intercept *)
PROCEDURE MultivariateTheilSen*(CONST X: Matrix; CONST y: Vector; VAR b: Vector;  VAR e: Vector);
VAR X0, slopes: Matrix; i,j,k,len:SIZE; dx: Vector; intercept, d, dy, sumx, slope, threshold, zero, inf, mininf: Scalar; random: Random.Generator;
	pca:MatrixPrincipalComponents.PCA;
	max,min:Scalar;
	columnMean, onesR: Vector;
BEGIN
	NEW(onesR, LEN(X,0)); onesR:=1;
	columnMean := (onesR * X)/LEN(X,0);
	X0 := X - onesR ** columnMean; (* PCA requires zero column mean input data *)

	NEW(pca, X0);
	X0:=pca.PrincipalComponents(); (* remove colinearity *)
	Util.OutMatrix(X0);

	(*choose sample pairs; here the extremal point pairs are used. Random pairs could also be used *)
	len:=MIN (200, LEN(X,0)*LEN(X,0));
	NEW(slopes, len, LEN(X0,1));
	NEW(random);
	NEW(b, LEN(X0,1)+1); (*include intercept*)
	inf:=1/zero; mininf:=-inf;
	min:=mininf; max:=inf;
	FOR i:=0 TO len-1 DO
		j:=ENTIER(random.Uniform() * LEN(X0,0));
		k:=ENTIER(random.Uniform() * LEN(X0,0));
		dx:=X0[k]-X0[j];
		sumx:=SUM(ABS(dx));
		dy:=y[k]-y[j];
		FOR j:=0 TO LEN(dx,0)-1 DO
			IF ABS(dx[j]) > 1.0E-20 THEN
				slopes[i,j]:=dy  * (dx[j]/sumx) /dx[j]; (* each dx contributes a part to dy *)
				max:=MAX(max, slopes[i,j]);
				min:=MIN(min, slopes[i,j]);
			ELSIF dx[j]=0 THEN slopes[i,j]:=0
			ELSE (*!  handling here must be improved  *)
				(*IF dy*dx[j]>=0 THEN slopes[i,j]:= inf
				ELSE slopes[i,j]:= mininf
				END;*)
				(*slopes[i,j]:=0*)
				IF ODD(i) THEN slopes[i,j]:=inf (*?=0?*)
				ELSE slopes[i,j]:=mininf (*?=0?*)
				END;
			END; (*? eps handing could be improved ?*)
		END;
	END;
	(*Util.OutMatrix(slopes);*)
	FOR i:=0 TO LEN(X0,1)-1 DO
		StatisticsBase.QSort(slopes[..,i]);
		b[i+1]:=slopes[len DIV 2,i]; (*choose median slope; b[0] is intercept *)
	END;
	Util.OutMatrix(slopes);
	e := (* y- *) X0*b[1..]; (*PCA yields zero mean data *)
	intercept:=SUM(y)/LEN(y,0);
	b[0]:=intercept;
	Util.OutVector(b); (*! to do: convert coordinates back to domain of X, not of X0*)
	Util.OutVector(y+e);
END MultivariateTheilSen;

(*solve P(t)= a e^(-bt) + c, for a,b,c 
whereby b is the decay time constant (=1/tau), a is dependent on the location of the start time, and c is the limes of P() at infinite time *)
(*mathematical solution contributed by Pascal Hunziker, 2023*)
PROCEDURE ExponentialRegression*(p0,slope0,slope1:Scalar; t0,t1:Scalar; VAR a,b,c:Scalar);
BEGIN
	(*preconditions*)
	ASSERT(slope0#0);
	ASSERT(t0#t1);
	ASSERT (slope1*slope0 > 0); (*same sign*)
	
	(*fundamental solution for t0=0 and t1=1 *)
	b:= -MathL.ln(slope1/slope0);
	
	(*normalize coefficients for arbitrary t0 and t1*)
	b := b/(t1-t0); (*longer interval=>smaller b*)
	a := -slope0/b;
	c := p0 - a;
END ExponentialRegression;

(* 
Given vectors x[..] and y[..] having 'degree+1' samples (e.g., 3 samples for quadratic polynomial)
y=a x^degree + ... + bx + c
find the coefficients a...
*)
PROCEDURE PolynomRegression*(CONST x,y: Vector; x0:Scalar; VAR coeff:Vector; degree:=2:SIGNED64); 
VAR 
	A:Matrix; 
	x1:Vector;
	i:SIZE;
	qr: MatrixStandardSolvers.QR; (*Cholesky will be faster, if matrices are positive definite*)
BEGIN
	(*preconditions*)
	ASSERT(LEN(x,0)=LEN(y,0),200);
	ASSERT(degree=2); (*implementation limitation*)
	
	NEW(A,LEN(x,0),degree+1);
	x1:=x-x0;
	A[..,degree]:=1;
	FOR i:=degree-1 TO 0 BY -1 DO
		A[..,i]:=A[..,i+1] .* x1;
	END;

	(*
	A[..,0]:=x-x0; A[..,0]:=A[..,0] .* A[..,0];
	A[..,1]:=x-x0;
	A[..,2]:=1;*)
	
	NEW(qr,A);
	coeff:=qr.Solve(y);
END PolynomRegression;

(* robust exponential regression: median of multiple exponential regressions that exploit one data point and 2 derivatives to compute parameters*)
TYPE RobustExponentialRegression*= OBJECT (*tested for experimental decay, not yet for experimental growth*)
	VAR 
		A,B,C, invB (*, A1,B1,C1,invB1*): Vector;
		avrgBeta*,avrgTau*, avrgLimes*, sdTau*, sdLimes*,sdBeta*, avrgSdBeta*, avrgSdTau*,avrgSdLimes*:MatrixBase.Datatype;(*optional bookkeeping*)
		nSamples, nOutliers:SIZE;
		random:Random.Generator;
	
	PROCEDURE &Init*(nSamples:SIZE);
	BEGIN
		SELF.nSamples:=nSamples;
		NEW(A,nSamples);
		NEW(B,nSamples);
		NEW(invB,nSamples);
		NEW(C,nSamples);
		NEW(random);
	END Init;
	
	PROCEDURE ReportVector*(CONST type:ARRAY OF CHAR):Vector;
	VAR d:Vector;
	BEGIN
		NEW(d,nSamples);
		IF type="a" THEN d:=A(*A1*)
		ELSIF type="beta" THEN d:=B; (*B1;*)
		ELSIF type="limes" THEN d:=C; (*C1;*)
		ELSIF type="tau" THEN d:=1/B; (* invB1;*)
		ELSE HALT(200)
		END;
		RETURN d
	END ReportVector;
	
	(* P(t)= a e^(-bt) + c *)
	(* tau= 1/b *)
	PROCEDURE Sampling*(CONST wave,waveDerivative: Vector; minT,maxT:SIZE; VAR b,tau, c: Scalar;(* VAR quality:Real;*) getStats:=FALSE:BOOLEAN); 
	VAR T0,T1:SIZE;
		i,j,jMax:SIZE;
		slope0,slope1,a0,b0,c0:Scalar;
		weight:Scalar;
		
		(*PROCEDURE InRange(x,low,high:Scalar):BOOLEAN;
		BEGIN
			RETURN ~Reals.IsNaNL(x) & (x>=low) & (x<=high)
		END InRange;*)
		
		BEGIN
			i:=0; j:=0; nOutliers:=0;
			jMax:=100*nSamples;
		
			WHILE i<nSamples DO
				IF maxT>minT+1 THEN
					T0:=minT + random.Dice(INTEGER(maxT+1-minT));
					T1:=minT + random.Dice(INTEGER(maxT+1-minT));
					slope0:=waveDerivative[T0];
					slope1:=waveDerivative[T1];
					IF (T0#T1)  & (slope0*slope1>0) & (ABS(T1-T0)>ABS(maxT-minT)/3) THEN
						ExponentialRegression(wave[T0],slope0, slope1, T0, T1,a0,b0,c0);
						IF  (c0<MIN(wave)) THEN (*!tbd: define criteria that to not result in wildly wrong results*)
							A[i]:=a0; 
							B[i]:=b0; 
							(*invB[i]:=1/b0;*)
							C[i]:=c0;
							INC(i);
						END;
					END;
				END;
				INC(j); IF j>jMax THEN i:=nSamples END; (*prevent infinite loop*)
			END;
			IF j<jMax THEN (*robust statistics*)
				
				(*invB:=1 / B; 
				tau:=StatisticsBase.DestructiveMedian(invB);*)
				
				b:=StatisticsBase.DestructiveMedian(B);
				tau:=1/b;
				c:=StatisticsBase.DestructiveMedian(C);
				
				(*optional bookkeeping, e.g. for use in data streams*)
				IF getStats & ~Reals.IsNaNL(b) & (b>=0) & ~Reals.IsNaNL(c) THEN
					sdBeta:=StatisticsBase.StandardDeviation(B); IF (avrgSdBeta=0) THEN avrgSdBeta:=sdBeta ELSE avrgSdBeta:=0.9*avrgSdBeta+0.1*sdBeta END;
					invB:=1/B;
					sdTau:=StatisticsBase.StandardDeviation(invB); IF (avrgSdTau=0) THEN avrgSdTau:=sdTau ELSE avrgSdTau:=0.9*avrgSdTau+0.1*sdTau END;
					sdLimes:=StatisticsBase.StandardDeviation(C); IF (avrgSdLimes=0) THEN avrgSdLimes:=sdLimes ELSE avrgSdLimes:=0.9*avrgSdLimes+0.1*sdLimes END;
					
					IF (sdBeta<avrgSdBeta) & (sdLimes<avrgSdLimes) THEN weight:=0.1 ELSE weight:=0.02 END;
					IF avrgBeta=0 	THEN avrgBeta:=b 		ELSE avrgBeta :=(1-weight)*avrgBeta+ weight*b END;
					IF avrgTau=0 	THEN avrgTau:=tau 		ELSE avrgTau :=(1-weight)*avrgTau+ weight*tau END;
					IF avrgLimes=0 THEN avrgLimes:=c 	ELSE avrgLimes:=(1-weight)*avrgLimes+ weight*c END;
				END;
			END;
		END Sampling;
		
	END RobustExponentialRegression;
	
	(* 
		robust spline estimate, using local polynomial approximation (oversampled) combined with  median of resulting parameters ..
		output node locations are evenly distributed along data array indices (not necessarily evenly distributed in x axis !)
	*)
	TYPE RobustSplineRegression* = OBJECT
		VAR 
			qr: MatrixStandardSolvers.QR; (*Cholesky will be faster, if matrices are positive definite*)
			A:Matrix; 
			coeffsM:Matrix;
			x1, xsamples,ysamples:Vector;
			degree:SIZE;
			
		PROCEDURE &Init*(CONST x,y: Vector; nCoeffs:SIZE; VAR Coeffs:Matrix; degree:=2, oversampling:=10:SIZE);
		VAR 
			step:FLOAT64;
			i,j,k,t,m,ind, stepN:SIZE;
			PROCEDURE NoDuplicates():BOOLEAN;
			BEGIN
				FOR k:=0 TO i DO
					IF x[ind]=xsamples[k] THEN RETURN FALSE END;
				END;
				RETURN TRUE
			END NoDuplicates;
		BEGIN
			ASSERT(nCoeffs>1,200);
			ASSERT(degree<4,201); (*implementation limitation*)
			
			SELF.degree:=degree;
			NEW(xsamples,degree+1);
			NEW(ysamples,degree+1);
			
			step:=(x[LEN(x,0)-1]-x[0]) / (nCoeffs-1);
			stepN:=LEN(x,0) DIV (nCoeffs-1);
			IF (LEN(Coeffs,0)#nCoeffs) OR (LEN(Coeffs,1)#(degree+1)) THEN NEW(Coeffs,nCoeffs,degree+1) END;
			IF (LEN(coeffsM,0)#oversampling) OR (LEN(coeffsM,1)#(degree+1)) THEN NEW(coeffsM,oversampling,degree+1) END;
			
			FOR t:=0 TO nCoeffs-1 DO
				FOR m:=0 TO oversampling-1 DO
					FOR i:=0 TO degree DO xsamples[i]:=-i END; (*prepare for noDuplicate test*)
					FOR i:=0 TO degree DO
						j:=t*stepN;
						REPEAT ind:=j-stepN DIV 2 + random.Dice(SIGNED32(stepN)+2) UNTIL (ind>=0)&(ind<LEN(x,0)) & NoDuplicates();
						xsamples[i]:=x[ind]; ysamples[i]:=y[ind];
					END;
					PolynomRegression(xsamples,ysamples,x[j],coeffsM[m,..]);
				END;
				(*Util.Out(coeffsM);*)
				FOR i:=0 TO degree DO
					Coeffs[t,i]:=StatisticsBase.DestructiveMedian(coeffsM[..,i])
				END;
			END;
			(*Util.Out(Coeffs);*)
		END Init;
		
		PROCEDURE PolynomRegression*(CONST x,y:Vector; x0:Scalar; VAR coeff:Vector);
			VAR 
				i:SIZE;
			BEGIN
				(*preconditions*)
				ASSERT(LEN(x,0)=LEN(y,0),200);
				
				IF (LEN(A,0)#LEN(x,0)) OR (LEN(A,1)#(degree+1)) THEN NEW(A,LEN(x,0),degree+1) END;
				x1:=x-x0;
				
				A[..,degree]:=1;(*[[x^n,...x,1],[],..,[]]*)
				FOR i:=degree-1 TO 0 BY -1 DO
					A[..,i]:=A[..,i+1] .* x1;
				END;
				IF qr=NIL THEN NEW(qr,A) ELSE qr.Init(A) END;
				coeff:=qr.Solve(y);
			END PolynomRegression;			
		END RobustSplineRegression;
	


	PROCEDURE Test*;
VAR X: Matrix; x, y, B,e: Vector; b,intercept:Scalar;
BEGIN
	y:=[1.02,2.1,2.91, 4.105, 5.0, 5.93,7.11, 8.03, 9.02, 10.01, 11.003]+2; (*note the intercept*)

	w.String("Linear Regression with intercept"); w.Ln; w.Update;
	X:=[[1.0,1.1,1.1],
		[1.0,1.9,2],
		[1,2.8,3.1],
		[1,4.1, 3.9],
		[1,5.3,5],
		[1,5.8,6],
		[1,7,7.1],
		[1,7.9,8],
		[1,9,8.9],
		[1,10.1,10],
		[1,11,11.1]
		];
	StatisticsLinearRegression.LinearRegression(X,y,B,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;

	w.String("Multivariate Robust Regression with intercept"); w.Ln; w.Update;
	X:=[[1.1,1.11],
		[1.9,2.05],
		[2.82,3.1],
		[4.1, 3.91],
		[5.3,5.103],
		[5.8,6.03],
		[7.12,7.1],
		[7.9,8.12],
		[9.03,8.9],
		[10.1,10.05],
		[11.05,11.1]
		];
	MultivariateTheilSen(X,y,B,e);
	w.String("b, e, error:"); w.Ln; w.Update; (*however, this b and e refer to the PCA transformed data ...*)
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	(*
	w.String("Univariate Robust Regression with intercept"); w.Ln; w.Update;
	x:=[1.1,
		1.9,
		2.8,
		4.1,
		5.3,
		5.8,
		7,
		7.9,
		9,
		10.1,
		11];
	TheilSenEstimator(x,y,b,intercept,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	*)
END Test;

PROCEDURE TestSort*;
VAR x: ARRAY [*] OF Scalar; i:SIZE;
	random:Random.Generator;
BEGIN
	 NEW(x,10);
	 NEW(random);
	 FOR i:=0 TO LEN(x,0)-1 DO
	 	x[i]:=random.Uniform();
	 END;
	 Util.OutVector(x);
	 StatisticsBase.QSort(x);
	 Util.OutVector(x);
END TestSort;

PROCEDURE TestExponential*;
CONST 
	alpha=1;
	beta=0.1;
	gamma=1.0;
VAR wave,waveDeriv: Vector;
	t:SIZE; 
	b,tau,c:Scalar;
	expRegression:RobustExponentialRegression;
BEGIN
	NEW(wave,10);
	NEW(waveDeriv,10);
	FOR t:=0 TO LEN(wave,0)-1 DO
		wave[t]:=alpha*MathL.exp(-beta*t)+gamma;
	END;
	FOR t:=1 TO LEN(waveDeriv,0)-2 DO
		waveDeriv[t]:=(wave[t+1]-wave[t-1])/2;
	END;
	NEW(expRegression,20);
	expRegression.Sampling(wave,waveDeriv,1,8,b,tau,c);
	ASSERT(ABS(b-beta) < beta/10);
	ASSERT(ABS(c-gamma)< gamma/10);
END TestExponential;

PROCEDURE TestSpline*;
CONST n=30;
VAR x,y,a,b, c: Vector;
	Coeffs:Matrix;
	t:SIZE; 
	sr:RobustSplineRegression;
BEGIN
	NEW(x,n); 
	NEW(y,n);
	NEW(a,n);
	NEW(b,n);
	NEW(c,n);
	
	FOR t:=0 TO LEN(x,0)-1 DO
		x[t]:=t;
		y[t]:=MathL.sin(t/2);
	END;
	Util.OutVector(x);
	Util.OutVector(y);
	
	NEW(sr, x,y, 10, Coeffs,3);
	Util.Out(Coeffs);
END TestSpline;

PROCEDURE TestPolynom*;
CONST n=20;
VAR x,y,coeff,a,b, c: Vector;
	t:SIZE; 
BEGIN
	NEW(x,n); 
	NEW(y,n);
	NEW(a,n);
	NEW(b,n);
	NEW(c,n);
	
	FOR t:=0 TO LEN(x,0)-1 DO
		x[t]:=t;
		y[t]:=MathL.sin(t);
	END;
	Util.OutVector(y);
	FOR t:=1 TO LEN(x,0)-2 DO
		PolynomRegression(x[t-1..t+1],y[t-1..t+1],x[t],coeff);
		a[t]:=coeff[0];
		b[t]:=coeff[1];
		c[t]:=coeff[2];
	END;
	Util.OutVector(a); 
	Util.OutVector(b); 
	Util.OutVector(c); 
END TestPolynom;


BEGIN
	NEW(random);
	Streams.OpenWriter(w, KernelLog.Send);
	eps0:=1; WHILE eps0 > 0 DO eps:=eps0; eps0:=eps/2 END;
	w.Float(eps, 30); w.Ln; w.Update;
END StatisticsRobustRegression.


StatisticsRobustRegression.Test ~
StatisticsRobustRegression.TestSort ~
StatisticsRobustRegression.TestExponential ~
StatisticsRobustRegression.TestSpline ~
StatisticsRobustRegression.TestPolynom ~

System.FreeDownTo StatisticsRobustRegression ~
