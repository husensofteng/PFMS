#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "math.h"
#include "limits.h"
#include "time.h"

#include "StringLib.h"
#include "MatrixLib.h"
#include "RandomLib.h"
#include "MathLib.h"
#include "MotifLib.h"
#include "SequenceLib.h"
#include "GenomeLib.h"
#include "MicroarrayLib.h"
#include "AffyLib.h"
#include "Alignment.h"
#include "WorkLib.h"

int Oct4GetPromoter(int argv, char **argc);
int ESClustGetPromoter_Write(struct SEQLINKMAP **pSegList, struct BYTEMATRIX *pCS,
							 int nC, int nMinSegLen, int nMaxGap, int nMinTotLen,
							 struct tagRefGene *pRefGene, FILE *fpOut, int *pId);


int main(int argv, char **argc)
{
	int nLen;
	int nseed;

	/* init rand */
	srand( (unsigned)time( NULL ) );
	if(strcmp(OS_SYSTEM, "WINDOWS") == 0)
	{
		nseed = (int)(rand()*1000/RAND_MAX);
	}
	else
	{
		nseed = rand()%1000;
	}
	rand_u_init(nseed);


	/* ---- */
	/* menu */
	/* ---- */
	Oct4GetPromoter(argv, argc);

	/* exit */
	exit(EXIT_SUCCESS);
}

int Oct4GetPromoter(int argv, char **argc)
{
	/* define */
	char strInFile[LINE_LENGTH];
	char strOutFile[LINE_LENGTH];
	char strLine[LONG_LINE_LENGTH];
	char strSpecies[LINE_LENGTH];
	char strGenomePath[LINE_LENGTH];
	char strCSPath[LINE_LENGTH];
	char strCSFile[LINE_LENGTH];
	int nC = 0;
	FILE *fpIn;
	FILE *fpOut;
	int nStart,nEnd;
	struct tagRefGene *pRefGene;
	int nTSSUP = 8000;
	int nTSSDOWN = 2000;
	int nIntronNum = 0;
	int nMinSegLen = 10;
	int nMaxGap = 50;
	int nMinTotLen = 100;

	int nTemp;
	int ni,nj;
	struct BYTEMATRIX *pCS;
	struct SEQLINKMAP *pSegList = NULL;
	struct SEQLINKMAP *pLinkSegList = NULL;
	struct SEQLINKMAP *pSeg = NULL;
	struct SEQLINKMAP *pCombinedSeg = NULL;
	struct SEQLINKMAP *pPrev = NULL;
	int nNewSeg = 0;
	int nId = 0;

	/* init */
	if(argv != 4)
	{
		printf("Error: parameter wrong!\n");
		exit(EXIT_FAILURE);
	}
	strcpy(strInFile, argc[1]);
	strcpy(strOutFile, argc[2]);
	nC = atoi(argc[3]);
	strcpy(strSpecies, "human");
	strcpy(strGenomePath, "/data/genomes/human/b35_hg17/");
	strcpy(strCSPath, "/data/genomes/human/b35_hg17/conservation/phastcons/");
	
	fpIn = NULL;
	fpIn = fopen(strInFile, "r");
	if(fpIn == NULL)
	{
		printf("Error: cannot open file!\n");
		exit(EXIT_FAILURE);
	}

	fpOut = NULL;
	fpOut = fopen(strOutFile, "w");
	if(fpOut == NULL)
	{
		printf("Error: cannot open file!\n");
		exit(EXIT_FAILURE);
	}

	while(fgets(strLine, LONG_LINE_LENGTH, fpIn)!=NULL)
	{
		StrTrimLeft(strLine);
		StrTrimRight(strLine);
		if(strLine[0] == '\0')
			continue;

		pRefGene = NULL;
		pRefGene = RefGeneCreate();
		RefGeneInit_FromGenomeLabFormat(pRefGene, strLine, strSpecies);

		/* promoter */
		if(pRefGene->chStrand == '+')
		{
			nStart = pRefGene->nTxStart-nTSSUP;
			nEnd = pRefGene->nTxStart+nTSSDOWN;
		}
		else
		{
			nStart = pRefGene->nTxEnd-nTSSDOWN;
			nEnd = pRefGene->nTxEnd+nTSSUP;
		}

		/* get conserved segments */
		sprintf(strCSFile, "%s%s.cs", strCSPath, pRefGene->strChrom);
		pCS = NULL;
		pCS = Genome_GetConsScore(strCSFile, nStart, nEnd);
		if(pCS != NULL)
		{
			for(nj=nStart; nj<=nEnd; nj++)
			{
				if((int)(pCS->pMatElement[nj-nStart]) > nC)
				{
					if(nNewSeg == 0)
					{
						pSeg = NULL;
						pSeg = SEQLINKMAPCREATE();
						pSeg->nGStart = nj;
						pSeg->nGEnd = nj;
						strcpy(pSeg->strGenome, pRefGene->strChrom);
						pSeg->chGStrand = pRefGene->chStrand;
						nNewSeg = 1;
					}
					else
					{
						pSeg->nGEnd = nj;
					}
				}
				else
				{
					if(nNewSeg == 1)
					{
						if(pSegList == NULL)
						{
							pSegList = pSeg;
							pPrev = pSeg;
						}
						else
						{
							pPrev->pNext = pSeg;
							pPrev = pSeg;
						}
						nNewSeg = 0;
					}
				}
			}
			
			if(nNewSeg == 1)
			{
				if(pSegList == NULL)
				{
					pSegList = pSeg;
					pPrev = pSeg;
				}
				else
				{
					pPrev->pNext = pSeg;
					pPrev = pSeg;
				}
				nNewSeg = 0;
			}
		}
		DestroyByteMatrix(pCS);
		ESClustGetPromoter_Write(&pSegList, pCS,
							 nC, nMinSegLen, nMaxGap, nMinTotLen,
							 pRefGene, fpOut, &nId);

		/* destroy refgene */
		RefGeneDestroy(pRefGene);
	}
	fclose(fpIn);
	fclose(fpOut);


	/* return */
	return PROC_SUCCESS;
}


int ESClustGetPromoter_Write(struct SEQLINKMAP **pSegList, struct BYTEMATRIX *pCS,
							 int nC, int nMinSegLen, int nMaxGap, int nMinTotLen,
							 struct tagRefGene *pRefGene, FILE *fpOut, int *pId)
{
	/* define */
	struct SEQLINKMAP *pLinkSegList = NULL;
	struct SEQLINKMAP *pSeg = NULL;
	struct SEQLINKMAP *pCombinedSeg = NULL;
	struct SEQLINKMAP *pPrev = NULL;
	int nNewSeg = 0;
	int nAddCombined;

	/* link segments */
	pCombinedSeg = NULL;
	while(*pSegList != NULL)
	{
		pSeg = *pSegList;
		*pSegList = pSeg->pNext;
		pSeg->pNext = NULL;
		
		if((pSeg->nGEnd-pSeg->nGStart+1) < nMinSegLen)
		{
			SEQLINKMAPDESTROY(pSeg);
			pSeg = NULL;
		}
		else
		{
			if(pCombinedSeg == NULL)
			{
				pCombinedSeg = pSeg;
			}
			else
			{
				if( (pSeg->nGStart-pCombinedSeg->nGEnd) <= nMaxGap )
				{
					pCombinedSeg->nGEnd = pSeg->nGEnd;
					nAddCombined = 0;
					SEQLINKMAPDESTROY(pSeg);
				}
				else
				{
					nAddCombined = 1;
				}
				
				if(nAddCombined == 1)
				{
					if((pCombinedSeg->nGEnd-pCombinedSeg->nGStart+1) < nMinTotLen)
					{
						SEQLINKMAPDESTROY(pCombinedSeg);
						pCombinedSeg = NULL;
					}
					else
					{
						if(pLinkSegList == NULL)
						{
							pLinkSegList = pCombinedSeg;
							pPrev = pCombinedSeg;
						}
						else
						{
							pPrev->pNext = pCombinedSeg;
							pPrev = pCombinedSeg;
						}
					}
					pCombinedSeg = pSeg;
				}
			}
		}
	}

	if(pCombinedSeg != NULL)
	{
		if((pCombinedSeg->nGEnd-pCombinedSeg->nGStart+1) < nMinTotLen)
		{
			SEQLINKMAPDESTROY(pCombinedSeg);
			pCombinedSeg = NULL;
		}
		else
		{
			if(pLinkSegList == NULL)
			{
				pLinkSegList = pCombinedSeg;
				pPrev = pCombinedSeg;
			}
			else
			{
				pPrev->pNext = pCombinedSeg;
				pPrev = pCombinedSeg;
			}
		}
	}


	/* write */
	while(pLinkSegList != NULL)
	{
		pSeg = pLinkSegList;
		pLinkSegList = pSeg->pNext;
		pSeg->pNext = NULL;

		fprintf(fpOut, "%d\t%s\t%d\t%d\t+\t", *pId, pSeg->strGenome, pSeg->nGStart, pSeg->nGEnd);
		RefGeneWrite(pRefGene, fpOut);
		(*pId) += 1;

		SEQLINKMAPDESTROY(pSeg);
	}

	/* return */
	return PROC_SUCCESS;
}