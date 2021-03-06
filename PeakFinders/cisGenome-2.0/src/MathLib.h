/* ----------------------------------------------------------------------- */
/*  MathLib.h : interface of the mathematics library                       */
/*  Author : Ji HongKai ; Time: 2004.07                                    */
/* ----------------------------------------------------------------------- */

/* ----------------------------------------------------------------------- */
/*                              Declaration                                */
/* ----------------------------------------------------------------------- */

/* ----------------------------------------------------------------------- */ 
/*                                 Struct                                  */
/* ----------------------------------------------------------------------- */ 

/* ----------------------------------------------------------------------- */
/*                            lnGamma Function                             */
/* Return ln(gamma(dx)).                                                   */
/* ----------------------------------------------------------------------- */
double gammaln(double dx);

/* ----------------------------------------------------------------------- */
/*                              Gamma Function                             */
/* Return gamma(dx).                                                       */
/* ----------------------------------------------------------------------- */
double gamma(double dx);

/* ----------------------------------------------------------------------- */
/*                           Factorial Function                            */
/* Return nx! = 1*2*...*nx.                                                */
/* ----------------------------------------------------------------------- */
double factorial(int nx);

/* ----------------------------------------------------------------------- */
/*                               Beta Function                             */
/* Return beta(dx).                                                        */
/* ----------------------------------------------------------------------- */
double beta(double da, double db);

/* ----------------------------------------------------------------------- */
/*                            Normal CDF Function                          */
/* Return normcdf(dx).                                                     */
/* ----------------------------------------------------------------------- */
double normcdf(double mu, double sigma, double dx);

/* ----------------------------------------------------------------------- */
/*                               Erf Function                              */
/* Return erf(dx).                                                         */
/* ----------------------------------------------------------------------- */
/* double erf(double dx); */

/* ----------------------------------------------------------------------- */
/*               Erf Function (Numerical Recipe Version)                   */
/* Return erf(dx).                                                         */
/* ----------------------------------------------------------------------- */
double erf(double dx);

/* ----------------------------------------------------------------------- */
/*                      Incomplete gamma function                          */
/* Return the incomplete gamma function P(a,x)                             */
/* ----------------------------------------------------------------------- */
double gammp(double da, double dx);

/* ----------------------------------------------------------------------- */
/*                       Incomplete Gamma Function                         */
/* Returns the incomplete gamma function P(a,x) evaluated by its series    */
/* representation as gamser. Also returns lnGamma(a) as gln.               */     
/* ----------------------------------------------------------------------- */
void gser(double *gamser, double da, double dx, double *gln);

/* ----------------------------------------------------------------------- */
/*                       Incomplete Gamma Function                         */
/* Returns the incomplete gamma function Q(a,x) evaluated by its continued */
/* fraction representation as gammcf. Also returns lnGamma(a) as gln.      */     
/* ----------------------------------------------------------------------- */
void gcf(double *gammcf, double da, double dx, double *gln);

/* ----------------------------------------------------------------------- */
/*                       Inverse Normal CDF Function                       */
/* Inverse of normal cumulative function.                                  */
/* ----------------------------------------------------------------------- */
double norminv(double mu, double sigma, double dx);