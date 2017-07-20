         MODULE SIPMODULE
         INTEGER, SAVE, POINTER          ::NPARM,IPCALC,IPRSIP
         REAL,    SAVE, POINTER          ::HCLOSE,ACCL
         REAL,    SAVE, DIMENSION(:),       POINTER   ::W
         REAL,    SAVE, DIMENSION(:,:,:),   POINTER   ::EL
         REAL,    SAVE, DIMENSION(:,:,:),   POINTER   ::FL
         REAL,    SAVE, DIMENSION(:,:,:),   POINTER   ::GL
         REAL,    SAVE, DIMENSION(:,:,:),   POINTER   ::V
         REAL,    SAVE, DIMENSION(:),       POINTER   ::HDCG
         INTEGER, SAVE, DIMENSION(:,:),     POINTER   ::LRCH
       TYPE SIPTYPE
         INTEGER,       POINTER          ::NPARM,IPCALC,IPRSIP
         REAL,          POINTER          ::HCLOSE,ACCL
         REAL,          DIMENSION(:),       POINTER   ::W
         REAL,          DIMENSION(:,:,:),   POINTER   ::EL
         REAL,          DIMENSION(:,:,:),   POINTER   ::FL
         REAL,          DIMENSION(:,:,:),   POINTER   ::GL
         REAL,          DIMENSION(:,:,:),   POINTER   ::V
         REAL,          DIMENSION(:),       POINTER   ::HDCG
         INTEGER,       DIMENSION(:,:),     POINTER   ::LRCH
       END TYPE
       TYPE(SIPTYPE),SAVE  ::SIPDAT(10)
      END MODULE SIPMODULE


      SUBROUTINE SIP7AR(IN,MXITER,IGRID)
C     ******************************************************************
C     ALLOCATE STORAGE FOR SIP ARRAYS AND READ SIP DATA
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      USE GLOBAL,    ONLY: IOUT,NCOL,NROW,NLAY
      USE SIPMODULE, ONLY: NPARM,IPCALC,IPRSIP,HCLOSE,ACCL,W,EL,FL,GL,
     1                     V,HDCG,LRCH
C
      CHARACTER*200 LINE
C     ------------------------------------------------------------------
      ALLOCATE(NPARM,IPCALC,IPRSIP,HCLOSE,ACCL)
C
C1------PRINT A MESSAGE IDENTIFYING SIP PACKAGE
      WRITE(IOUT,1)IN
    1 FORMAT(1X,
     1   /1X,'SIP -- STRONGLY-IMPLICIT PROCEDURE SOLUTION PACKAGE',
     2   /20X,'VERSION 7, 5/2/2005',' INPUT READ FROM UNIT ',I4)
C
C2------READ AND PRINT COMMENTS, MXITER, AND NPARM
      CALL URDCOM(IN,IOUT,LINE)
      LLOC=1
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,MXITER,R,IOUT,IN)
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,NPARM,R,IOUT,IN)
      WRITE(IOUT,3) MXITER,NPARM
    3 FORMAT(1X,'MAXIMUM OF',I4,' ITERATIONS ALLOWED FOR CLOSURE'/
     1       1X,I2,' ITERATION PARAMETERS')
C
C3------ALLOCATE SPACE FOR THE SIP ARRAYS
      ALLOCATE(EL(NCOL,NROW,NLAY))
      ALLOCATE(FL(NCOL,NROW,NLAY))
      ALLOCATE(GL(NCOL,NROW,NLAY))
      ALLOCATE(V(NCOL,NROW,NLAY))
      ALLOCATE(W(NPARM))
      ALLOCATE(LRCH(3,MXITER))
      ALLOCATE(HDCG(MXITER))
C
C4------READ ACCL,HCLOSE,WSEED,IPCALC,IPRSIP
      READ(IN,*) ACCL,HCLOSE,IPCALC,WSEED,IPRSIP
      ZERO=0.
      IF(ACCL.EQ.ZERO) ACCL=1.
      IF(IPRSIP.LE.0)IPRSIP=999
C
C5------PRINT DATA VALUES JUST READ
      WRITE(IOUT,100)
  100 FORMAT(1X,/10X,'SOLUTION BY THE STRONGLY IMPLICIT PROCEDURE'
     1   /10X,43('-'))
      WRITE(IOUT,115) MXITER
  115 FORMAT(1X,'MAXIMUM ITERATIONS ALLOWED FOR CLOSURE =',I9)
      WRITE(IOUT,120) ACCL
  120 FORMAT(1X,16X,'ACCELERATION PARAMETER =',G15.5)
      WRITE(IOUT,125) HCLOSE
  125 FORMAT(1X,5X,'HEAD CHANGE CRITERION FOR CLOSURE =',E15.5)
      WRITE(IOUT,130) IPRSIP
  130 FORMAT(1X,5X,'SIP HEAD CHANGE PRINTOUT INTERVAL =',I9)
C
C6------CHECK IF SPECIFIED VALUE OF WSEED SHOULD BE USED OR IF
C6------SEED SHOULD BE CALCULATED
      IF(IPCALC.NE.0) THEN
C
C6A-----CALCULATE SEED & ITERATION PARAMETERS PRIOR TO 1ST ITERATION
         WRITE(IOUT,140)
  140    FORMAT(1X,/5X,'CALCULATE ITERATION PARAMETERS FROM MODEL',
     1   ' CALCULATED WSEED')
      ELSE
C
C6B-----USE SPECIFIED VALUE OF WSEED
C6B-----CALCULATE AND PRINT ITERATION PARAMETERS
  150    ONE=1.
         P1=-ONE
         P2=NPARM-1
         DO 160 I=1,NPARM
         P1=P1+ONE
  160    W(I)=ONE-WSEED**(P1/P2)
         WRITE(IOUT,161) NPARM,WSEED,(W(J),J=1,NPARM)
  161    FORMAT(1X,/1X,I5,' ITERATION PARAMETERS CALCULATED FROM',
     1     ' SPECIFIED WSEED =',F11.8,' :'//(1X,5E13.6))
      END IF
C
C7------RETURN
      CALL SIP7PSV(IGRID)
      RETURN
      END
      SUBROUTINE SIP7AP(HNEW,IBOUND,CR,CC,CV,HCOF,RHS,EL,FL,GL,V,
     1      W,HDCG,LRCH,NPARM,KITER,HCLOSE,ACCL,ICNVG,KSTP,KPER,
     2      IPCALC,IPRSIP,MXITER,NSTP,NCOL,NROW,NLAY,NODES,IOUT,MUTSIP,
     3      IERR)
C     ******************************************************************
C     SOLUTION BY THE STRONGLY IMPLICIT PROCEDURE -- 1 ITERATION
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DOUBLE PRECISION HNEW,DITPAR,AC,HHCOF,RRHS,XI,DZERO,DONE,RES
      DOUBLE PRECISION Z,B,D,E,F,H,S,AP,TP,CP,GP,UP,RP
      DOUBLE PRECISION ZHNEW,BHNEW,DHNEW,FHNEW,HHNEW,SHNEW
      DOUBLE PRECISION AL,BL,CL,DL,ELNCL,FLNCL,GLNCL
      DOUBLE PRECISION ELNRL,FLNRL,GLNRL,ELNLL,FLNLL,GLNLL
      DOUBLE PRECISION VNRL,VNCL,VNLL,ELXI,FLXI,GLXI,VN
      DOUBLE PRECISION RHS, HCOF
C
      DIMENSION HNEW(NODES), IBOUND(NODES), CR(NODES), CC(NODES),
     1  CV(NODES), HCOF(NODES), RHS(NODES), EL(NODES), FL(NODES),
     2  GL(NODES), V(NODES), W(NPARM), HDCG(MXITER), LRCH(3,MXITER)
C     ------------------------------------------------------------------
C
C1------CALCULATE ITERATION PARAMETERS IF FLAG IS SET.  THEN
C1------CLEAR THE FLAG SO THAT CALCULATION IS DONE ONLY ONCE.
      IF(IPCALC.NE.0)
     1     CALL SSIP7I(CR,CC,CV,IBOUND,NPARM,W,NCOL,NROW,NLAY,IOUT)
      IPCALC=0
C
C2------ASSIGN VALUES TO FIELDS THAT ARE CONSTANT DURING AN ITERATION
      ZERO=0.
      DZERO=ZERO
      DONE=1.
      AC=ACCL
      NRC=NROW*NCOL
      NTH=MOD(KITER-1,NPARM)+1
      DITPAR=W(NTH)
C
C3------INITIALIZE VARIABLE THAT TRACKS MAXIMUM HEAD CHANGE DURING
C3------THE ITERATION
      BIGG=ZERO
      BIG=ZERO
      IB=0
      JB=0
      KB=0
C
C4------CLEAR SIP WORK ARRAYS.
      DO 100 I=1,NODES
      EL(I)=ZERO
      FL(I)=ZERO
      GL(I)=ZERO
  100 V(I)=ZERO
C
C5------SET NORMAL/REVERSE EQUATION ORDERING FLAG (1 OR -1) AND
C5------CALCULATE INDEXES DEPENDENT ON ORDERING
      IDIR=1
      IF(MOD(KITER,2).EQ.0)IDIR=-1
      IDNRC=IDIR*NRC
      IDNCOL=IDIR*NCOL
C
C6------STEP THROUGH CELLS CALCULATING INTERMEDIATE VECTOR V
C6------USING FORWARD SUBSTITUTION
      DO 150 K=1,NLAY
      DO 150 I=1,NROW
      DO 150 J=1,NCOL
C
C6A-----SET UP CURRENT CELL LOCATION INDEXES.  THESE ARE DEPENDENT
C6A-----ON THE DIRECTION OF EQUATION ORDERING.
      IF(IDIR.LE.0)GO TO 120
      II=I
      JJ=J
      KK=K
      GO TO 122
  120 II=NROW-I+1
      JJ=J
      KK=NLAY-K+1
C
C6B-----CALCULATE 1 DIMENSIONAL SUBSCRIPT OF CURRENT CELL AND
C6B-----SKIP CALCULATIONS IF CELL IS NOFLOW OR CONSTANT HEAD
  122 N=JJ+(II-1)*NCOL+(KK-1)*NRC
      IF(IBOUND(N).LE.0)GO TO 150
C
C6C-----CALCULATE 1 DIMENSIONAL SUBSCRIPTS FOR LOCATING THE 6
C6C-----SURROUNDING CELLS
      NRN=N+IDNCOL
      NRL=N-IDNCOL
      NCN=N+1
      NCL=N-1
      NLN=N+IDNRC
      NLL=N-IDNRC
C
C6D-----CALCULATE 1 DIMENSIONAL SUBSCRIPTS FOR CONDUCTANCE TO THE 6
C6D-----SURROUNDING CELLS.  THESE DEPEND ON ORDERING OF EQUATIONS.
      IF(IDIR.LE.0)GO TO 124
      NCF=N
      NCD=NCL
      NRB=NRL
      NRH=N
      NLS=N
      NLZ=NLL
      GO TO 126
  124 NCF=N
      NCD=NCL
      NRB=N
      NRH=NRN
      NLS=NLN
      NLZ=N
C
C6E-----ASSIGN VARIABLES IN MATRICES A & U INVOLVING ADJACENT CELLS
C6E1----NEIGHBOR IS 1 ROW BACK
  126 B=DZERO
      ELNRL=DZERO
      FLNRL=DZERO
      GLNRL=DZERO
      BHNEW=DZERO
      VNRL=DZERO
      IF(I.EQ.1) GO TO 128
      B=CC(NRB)
      ELNRL=EL(NRL)
      FLNRL=FL(NRL)
      GLNRL=GL(NRL)
      BHNEW=B*HNEW(NRL)
      VNRL=V(NRL)
C
C6E2----NEIGHBOR IS 1 ROW AHEAD
  128 H=DZERO
      HHNEW=DZERO
      IF(I.EQ.NROW) GO TO 130
      H=CC(NRH)
      HHNEW=H*HNEW(NRN)
C
C6E3----NEIGHBOR IS 1 COLUMN BACK
  130 D=DZERO
      ELNCL=DZERO
      FLNCL=DZERO
      GLNCL=DZERO
      DHNEW=DZERO
      VNCL=DZERO
      IF(J.EQ.1) GO TO 132
      D=CR(NCD)
      ELNCL=EL(NCL)
      FLNCL=FL(NCL)
      GLNCL=GL(NCL)
      DHNEW=D*HNEW(NCL)
      VNCL=V(NCL)
C
C6E4----NEIGHBOR IS 1 COLUMN AHEAD
  132 F=DZERO
      FHNEW=DZERO
      IF(J.EQ.NCOL) GO TO 134
      F=CR(NCF)
      FHNEW=F*HNEW(NCN)
C
C6E5----NEIGHBOR IS 1 LAYER BEHIND
  134 Z=DZERO
      ELNLL=DZERO
      FLNLL=DZERO
      GLNLL=DZERO
      ZHNEW=DZERO
      VNLL=DZERO
      IF(K.EQ.1) GO TO 136
      Z=CV(NLZ)
      ELNLL=EL(NLL)
      FLNLL=FL(NLL)
      GLNLL=GL(NLL)
      ZHNEW=Z*HNEW(NLL)
      VNLL=V(NLL)
C
C6E6----NEIGHBOR IS 1 LAYER AHEAD
  136 S=DZERO
      SHNEW=DZERO
      IF(K.EQ.NLAY) GO TO 138
      S=CV(NLS)
      SHNEW=S*HNEW(NLN)
C
C6E7----CALCULATE THE NEGATIVE SUM OF ALL CONDUCTANCES TO NEIGHBORING
C6E7----CELLS
  138 E=-Z-B-D-F-H-S
C
C6F-----CALCULATE COMPONENTS OF THE UPPER AND LOWER MATRICES, WHICH
C6F-----ARE THE FACTORS OF MATRIX (A+B)
      AL=Z/(DONE+DITPAR*(ELNLL+FLNLL))
      BL=B/(DONE+DITPAR*(ELNRL+GLNRL))
      CL=D/(DONE+DITPAR*(FLNCL+GLNCL))
      AP=AL*ELNLL
      CP=BL*ELNRL
      GP=CL*FLNCL
      RP=CL*GLNCL
      TP=AL*FLNLL
      UP=BL*GLNRL
      HHCOF=HCOF(N)
      DL=E+HHCOF+DITPAR*(AP+TP+CP+GP+UP+RP)-AL*GLNLL-BL*FLNRL-CL*ELNCL
      IF(DL.EQ.DZERO) THEN
         WRITE(IOUT,139) KK,II,JJ
139      FORMAT(1X,/1X,'DIVIDE BY 0 IN SIP AT LAYER',I3,',  ROW',I4,
     1   ',  COLUMN',I4,/
     2   1X,'THIS CAN OCCUR WHEN A CELL IS CONNECTED TO THE REST OF',/
     3   1X,'THE MODEL THROUGH A SINGLE CONDUCTANCE BRANCH.  CHECK',/
     4   1X,'FOR THIS SITUATION AT THE INDICATED CELL.')
         IERR = 1
         RETURN
      END IF
      EL(N)=(F-DITPAR*(AP+CP))/DL
      FL(N)=(H-DITPAR*(TP+GP))/DL
      GL(N)=(S-DITPAR*(RP+UP))/DL
C
C6G-----CALCULATE THE RESIDUAL
      RRHS=RHS(N)
      RES=RRHS-ZHNEW-BHNEW-DHNEW-E*HNEW(N)-HHCOF*HNEW(N)-FHNEW-HHNEW
     1      -SHNEW
C
C6H-----CALCULATE THE INTERMEDIATE VECTOR V
      V(N)=(AC*RES-AL*VNLL-BL*VNRL-CL*VNCL)/DL
C
  150 CONTINUE
C
C7------STEP THROUGH EACH CELL AND SOLVE FOR HEAD CHANGE BY BACK
C7------SUBSTITUTION
      DO 160 K=1,NLAY
      DO 160 I=1,NROW
      DO 160 J=1,NCOL
C
C7A-----SET UP CURRENT CELL LOCATION INDEXES.  THESE ARE DEPENDENT
C7A-----ON THE DIRECTION OF EQUATION ORDERING.
      IF(IDIR.LT.0) GO TO 152
      KK=NLAY-K+1
      II=NROW-I+1
      JJ=NCOL-J+1
      GO TO 154
  152 KK=K
      II=I
      JJ=NCOL-J+1
C
C7B-----CALCULATE 1 DIMENSIONAL SUBSCRIPT OF CURRENT CELL AND
C7B-----SKIP CALCULATIONS IF CELL IS NOFLOW OR CONSTANT HEAD
  154 N=JJ+(II-1)*NCOL+(KK-1)*NRC
      IF(IBOUND(N).LE.0)GO TO 160
C
C7C-----CALCULATE 1 DIMENSIONAL SUBSCRIPTS FOR THE 3 NEIGHBORING CELLS
C7C-----BEHIND (RELATIVE TO THE DIRECTION OF THE BACK SUBSTITUTION
C7C-----ORDERING) THE CURRRENT CELL.
      NC=N+1
      NR=N+IDNCOL
      NL=N+IDNRC
C
C7D-----BACK SUBSTITUTE, STORING HEAD CHANGE IN ARRAY V IN PLACE OF
C7D-----INTERMEDIATE FORWARD SUBSTITUTION VALUES.
      ELXI=DZERO
      FLXI=DZERO
      GLXI=DZERO
      IF(JJ.NE.NCOL) ELXI=EL(N)*V(NC)
      IF(I.NE.1) FLXI=FL(N)*V(NR)
      IF(K.NE.1) GLXI=GL(N)*V(NL)
      VN=V(N)
      V(N)=VN-ELXI-FLXI-GLXI
C
C7E-----GET THE ABSOLUTE HEAD CHANGE. IF IT IS MAX OVER GRID SO FAR.
C7E-----THEN SAVE IT ALONG WITH CELL INDICES AND HEAD CHANGE.
      TCHK=ABS(V(N))
      IF (TCHK.LE.BIGG) GO TO 155
      BIGG=TCHK
      BIG=V(N)
      IB=II
      JB=JJ
      KB=KK
C
C7F-----ADD HEAD CHANGE THIS ITERATION TO HEAD FROM THE PREVIOUS
C7F-----ITERATION TO GET A NEW ESTIMATE OF HEAD.
  155 XI=V(N)
      HNEW(N)=HNEW(N)+XI
C
  160 CONTINUE
C
C8------STORE THE LARGEST ABSOLUTE HEAD CHANGE (THIS ITERATION) AND
C8------AND ITS LOCATION.
      HDCG(KITER)=BIG
      LRCH(1,KITER)=KB
      LRCH(2,KITER)=IB
      LRCH(3,KITER)=JB
      ICNVG=0
      IF(BIGG.LE.HCLOSE) ICNVG=1
C
C9------IF END OF TIME STEP, PRINT # OF ITERATIONS THIS STEP
      IF(ICNVG.EQ.0 .AND. KITER.NE.MXITER) GO TO 600
      IF(MUTSIP.LT.2) THEN
         IF(KSTP.EQ.1) WRITE(IOUT,500)
  500    FORMAT(1X)
         WRITE(IOUT,501) KITER,KSTP,KPER
  501    FORMAT(1X,I5,' ITERATIONS FOR TIME STEP',I4,
     1     ' IN STRESS PERIOD ',I4)
      END IF
C
C10-----PRINT HEAD CHANGE EACH ITERATION IF PRINTOUT INTERVAL IS REACHED
      IF(MUTSIP.EQ.0) THEN
         IF(ICNVG.EQ.0 .OR. KSTP.EQ.NSTP .OR. MOD(KSTP,IPRSIP).EQ.0)
     1      CALL SSIP7P(HDCG,LRCH,KITER,MXITER,IOUT)
      ELSE IF(MUTSIP.EQ.3 .AND. ICNVG.EQ.0) THEN
         CALL SSIP7P(HDCG,LRCH,KITER,MXITER,IOUT)
      END IF
C
C11-----RETURN
600   RETURN
C
      END
      SUBROUTINE SSIP7I(CR,CC,CV,IBOUND,NPARM,W,NCOL,NROW,NLAY,
     1          IOUT)
C     ******************************************************************
C     CALCULATE AN ITERATION PARAMETER SEED AND USE IT TO CALCULATE SIP
C     ITERATION PARAMETERS
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DIMENSION CR(NCOL,NROW,NLAY),CC(NCOL,NROW,NLAY)
     1       ,CV(NCOL,NROW,NLAY),IBOUND(NCOL,NROW,NLAY),W(NPARM)
C
      DOUBLE PRECISION DWMIN,AVGSUM
C     ------------------------------------------------------------------
C
C1------CALCULATE CONSTANTS AND INITIALIZE VARIABLES
      ZERO=0.
      ONE=1.
      TWO=2.
      PIEPIE=9.869604
      R=NROW
      C=NCOL
      ZL=NLAY
      CCOL=PIEPIE/(TWO*C*C)
      CROW=PIEPIE/(TWO*R*R)
      CLAY=PIEPIE/(TWO*ZL*ZL)
      WMINMN=ONE
      AVGSUM=ZERO
      NODES=0
C
C2------LOOP THROUGH ALL CELLS, CALCULATING A SEED FOR EACH CELL
C2------THAT IS ACTIVE
      DO 100 K=1,NLAY
      DO 100 I=1,NROW
      DO 100 J=1,NCOL
      IF(IBOUND(J,I,K).LE.0) GO TO 100
C
C2A-----CONDUCTANCE FROM THIS CELL
C2A-----TO EACH OF THE 6 ADJACENT CELLS
      D=ZERO
      IF(J.NE.1) D=CR(J-1,I,K)
      F=ZERO
      IF(J.NE.NCOL) F=CR(J,I,K)
      B=ZERO
      IF(I.NE.1) B=CC(J,I-1,K)
      H=ZERO
      IF(I.NE.NROW) H=CC(J,I,K)
      Z=ZERO
      IF(K.NE.1) Z=CV(J,I,K-1)
      S=ZERO
      IF(K.NE.NLAY) S=CV(J,I,K)
C
C2B-----FIND THE MAXIMUM AND MINIMUM OF THE 2 CONDUCTANCE COEFFICIENTS
C2B-----IN EACH PRINCIPAL COORDINATE DIRECTION
      DFMX=MAX(D,F)
      BHMX=MAX(B,H)
      ZSMX=MAX(Z,S)
      DFMN=MIN(D,F)
      BHMN=MIN(B,H)
      ZSMN=MIN(Z,S)
      IF(DFMN.EQ.ZERO) DFMN=DFMX
      IF(BHMN.EQ.ZERO) BHMN=BHMX
      IF(ZSMN.EQ.ZERO) ZSMN=ZSMX
C
C2C-----CALCULATE A SEED IN EACH PRINCIPAL COORDINATE DIRECTION
      WCOL=ONE
      IF(DFMN.NE.ZERO) WCOL=CCOL/(ONE+(BHMX+ZSMX)/DFMN)
      WROW=ONE
      IF(BHMN.NE.ZERO) WROW=CROW/(ONE+(DFMX+ZSMX)/BHMN)
      WLAY=ONE
      IF(ZSMN.NE.ZERO) WLAY=CLAY/(ONE+(DFMX+BHMX)/ZSMN)
C
C2D-----SELECT THE CELL SEED, WHICH IS THE MINIMUM SEED OF THE 3.
C2D-----SELECT THE MINIMUM SEED OVER THE WHOLE GRID.
      WMIN=MIN(WCOL,WROW,WLAY)
      WMINMN=MIN(WMINMN,WMIN)
C
C2E-----ADD THE CELL SEED TO THE ACCUMULATOR AVGSUM FOR USE
C2E-----IN GETTING THE AVERAGE SEED.
      DWMIN=WMIN
      AVGSUM=AVGSUM+DWMIN
      NODES=NODES+1
C
  100 CONTINUE
C
C3------CALCULATE THE AVERAGE SEED OF THE CELL SEEDS, AND PRINT
C3------THE AVERAGE AND MINIMUM SEEDS.
      TMP=NODES
      AVGMIN=AVGSUM
      AVGMIN=AVGMIN/TMP
      WRITE(IOUT,101) AVGMIN,WMINMN
  101 FORMAT(1X,/1X,'AVERAGE SEED =',F11.8/1X,'MINIMUM SEED =',F11.8)
C
C4------CALCULATE AND PRINT ITERATION PARAMETERS FROM THE AVERAGE SEED
      P1=-ONE
      P2=NPARM-1
      DO 50 I=1,NPARM
      P1=P1+ONE
   50 W(I)=ONE-AVGMIN**(P1/P2)
      WRITE(IOUT,150) NPARM,(W(J),J=1,NPARM)
  150 FORMAT(1X,/1X,I5,' ITERATION PARAMETERS CALCULATED FROM',
     1      ' AVERAGE SEED:'//(1X,5E13.6))
C
C5------RETURN
      RETURN
      END
      SUBROUTINE SSIP7P(HDCG,LRCH,KITER,MXITER,IOUT)
C     ******************************************************************
C     PRINT MAXIMUM HEAD CHANGE FOR EACH ITERATION DURING A TIME STEP
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
C
      DIMENSION HDCG(MXITER), LRCH(3,MXITER)
C     ------------------------------------------------------------------
C
      WRITE(IOUT,5)
5     FORMAT(1X,/1X,'MAXIMUM HEAD CHANGE FOR EACH ITERATION:',/
     1       1X,/1X,5('   HEAD CHANGE'),/
     2           1X,5(' LAYER,ROW,COL')/1X,70('-'))
      NGRP=(KITER-1)/5 +1
      DO 20 K=1,NGRP
         L1=(K-1)*5 +1
         L2=L1+4
         IF(K.EQ.NGRP) L2=KITER
         WRITE(IOUT,10) (HDCG(J),J=L1,L2)
         WRITE(IOUT,11) ((LRCH(I,J),I=1,3),J=L1,L2)
10       FORMAT(1X,5G14.4)
11       FORMAT(1X,5(:' (',I3,',',I3,',',I3,')'))
20    CONTINUE
      WRITE(IOUT,12)
12    FORMAT(1X)
C
      RETURN
C
      END
      SUBROUTINE SIP7DA(IGRID)
C  Deallocate SIP DATA
      USE SIPMODULE
C
      CALL SIP7PNT(IGRID)
        DEALLOCATE(NPARM,IPCALC,IPRSIP,HCLOSE,ACCL)
        DEALLOCATE(EL)
        DEALLOCATE(FL)
        DEALLOCATE(GL)
        DEALLOCATE(V)
        DEALLOCATE(W)
        DEALLOCATE(LRCH)
        DEALLOCATE(HDCG)
C
      RETURN
      END
      SUBROUTINE SIP7PNT(IGRID)
C  Set pointers to SIP data for a grid
      USE SIPMODULE
C
      NPARM=>SIPDAT(IGRID)%NPARM
      IPCALC=>SIPDAT(IGRID)%IPCALC
      IPRSIP=>SIPDAT(IGRID)%IPRSIP
      HCLOSE=>SIPDAT(IGRID)%HCLOSE
      ACCL=>SIPDAT(IGRID)%ACCL
      EL=>SIPDAT(IGRID)%EL
      FL=>SIPDAT(IGRID)%FL
      GL=>SIPDAT(IGRID)%GL
      V=>SIPDAT(IGRID)%V
      W=>SIPDAT(IGRID)%W
      LRCH=>SIPDAT(IGRID)%LRCH
      HDCG=>SIPDAT(IGRID)%HDCG
C
      RETURN
      END

      SUBROUTINE SIP7PSV(IGRID)
C  Save pointers to SIP data
      USE SIPMODULE
C
      SIPDAT(IGRID)%NPARM=>NPARM
      SIPDAT(IGRID)%IPCALC=>IPCALC
      SIPDAT(IGRID)%IPRSIP=>IPRSIP
      SIPDAT(IGRID)%HCLOSE=>HCLOSE
      SIPDAT(IGRID)%ACCL=>ACCL
      SIPDAT(IGRID)%EL=>EL
      SIPDAT(IGRID)%FL=>FL
      SIPDAT(IGRID)%GL=>GL
      SIPDAT(IGRID)%V=>V
      SIPDAT(IGRID)%W=>W
      SIPDAT(IGRID)%LRCH=>LRCH
      SIPDAT(IGRID)%HDCG=>HDCG
C
      RETURN
      END
