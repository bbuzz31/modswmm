      MODULE DE4MODULE
        INTEGER,SAVE,POINTER  ::MXUP,MXLOW,MXEQ,MXBW,ITMX,ID4DIR
        INTEGER,SAVE,POINTER  ::NITERDE4,IFREQ,IPRD4,MUTD4,ID4DIM
        INTEGER,SAVE,POINTER  ::NBWL,NUPL,NLOWL,NLOW,NEQ,NUP,NBW
        REAL   ,SAVE,POINTER  ::ACCLDE4,HCLOSEDE4,DELTL
        INTEGER,          SAVE, POINTER, DIMENSION(:,:)   ::IUPPNT
        INTEGER,          SAVE, POINTER, DIMENSION(:,:,:) ::IEQPNT
        REAL,             SAVE, POINTER, DIMENSION(:,:)   ::AU
        REAL,             SAVE, POINTER, DIMENSION(:,:)   ::AL
        REAL,             SAVE, POINTER, DIMENSION(:)     ::D4B
        REAL,             SAVE, POINTER, DIMENSION(:)     ::HDCGDE4
        INTEGER,          SAVE, POINTER, DIMENSION(:,:)   ::LRCHDE4
      TYPE DE4TYPE
        INTEGER,POINTER  ::MXUP,MXLOW,MXEQ,MXBW,ITMX,ID4DIR
        INTEGER,POINTER  ::NITERDE4,IFREQ,IPRD4,MUTD4,ID4DIM
        INTEGER,POINTER  ::NBWL,NUPL,NLOWL,NLOW,NEQ,NUP,NBW
        REAL   ,POINTER  ::ACCLDE4,HCLOSEDE4,DELTL
        INTEGER,           POINTER, DIMENSION(:,:)   ::IUPPNT
        INTEGER,           POINTER, DIMENSION(:,:,:) ::IEQPNT
        REAL,              POINTER, DIMENSION(:,:)   ::AU
        REAL,              POINTER, DIMENSION(:,:)   ::AL
        REAL,              POINTER, DIMENSION(:)     ::D4B
        REAL,              POINTER, DIMENSION(:)     ::HDCGDE4
        INTEGER,           POINTER, DIMENSION(:,:)   ::LRCHDE4
      END TYPE
      TYPE(DE4TYPE), SAVE ::DE4DAT(10)
      END MODULE DE4MODULE


      SUBROUTINE DE47AR(INDE4,MXITER,IGRID)
C     ******************************************************************
C     ALLOCATE STORAGE IN X ARRAY FOR D4 ARRAYS
C     ******************************************************************
C
C     SPECIFICATIONS:
C     ------------------------------------------------------------------
      USE GLOBAL,   ONLY:IOUT,NCOL,NROW,NLAY
      USE DE4MODULE
      CHARACTER*200 LINE
C     ------------------------------------------------------------------
      ALLOCATE(MXUP,MXLOW,MXEQ,MXBW,ITMX,ID4DIR)
      ALLOCATE(NITERDE4,IFREQ,IPRD4,MUTD4,ID4DIM)
      ALLOCATE(NBWL,NUPL,NLOWL,NLOW,NEQ,NUP,NBW)
      ALLOCATE(ACCLDE4,HCLOSEDE4,DELTL)
C
C1------PRINT A MESSAGE IDENTIFYING DE4 PACKAGE.
      WRITE(IOUT,1) INDE4
    1 FORMAT(1X,/1X,'DE4 -- D4 DIRECT SOLUTION PACKAGE',
     1    ', VERSION 7, 5/2/2005  INPUT READ FROM UNIT ',I4)
C
C2------CALCULATE DEFAULT VALUES FOR MXUP, MXLOW, AND MXBW.
C2------ALSO SET VALUES FOR ID4DIR (DIRECTION OF EQUATION ORDERING) AND
C2------ID4DIM (MAXIMUM NUMBER OF HEAD COEFFICIENTS FOR ONE EQUATION).
C2------ID4DIM=5 for a 2-D problem; ID4DIM=7 for 3-D.
      NODES=NCOL*NROW*NLAY
      NHALFU=(NODES-1)/2 +1
      NHALFL=NODES-NHALFU
      ID4DIM=7
      DELTL = 0.
      NBWL = 0
      NUPL = 0
      NLOWL = 0
      IF(NLAY.LE.NCOL .AND. NLAY.LE.NROW) THEN
         IF(NLAY.EQ.1) ID4DIM=5
         IF(NCOL.GE.NROW) THEN
            ID4DIR=1
            NBWGRD=NROW*NLAY+1
         ELSE
            ID4DIR=2
            NBWGRD=NCOL*NLAY+1
         END IF
      ELSE IF(NROW.LE.NCOL .AND. NROW.LE.NLAY) THEN
         IF(NROW.EQ.1) ID4DIM=5
         IF(NCOL.GE.NLAY) THEN
            ID4DIR=3
            NBWGRD=NROW*NLAY+1
         ELSE
            ID4DIR=4
            NBWGRD=NROW*NCOL+1
         END IF
      ELSE
         IF(NCOL.EQ.1) ID4DIM=5
         IF(NROW.GE.NLAY) THEN
            ID4DIR=5
            NBWGRD=NCOL*NLAY+1
         ELSE
            ID4DIR=6
            NBWGRD=NCOL*NROW+1
         END IF
      END IF
C
C3------READ AND PRINT COMMENTS, ITMX, MXUP, MXLOW, MXBW.  FOR ANY
C3------ZERO OR NEGATIVE VALUES, SUBSTITUE THE DEFAULT VALUE.
      CALL URDCOM(INDE4,IOUT,LINE)
      LLOC=1
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,ITMX,R,IOUT,INDE4)
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,MXUP,R,IOUT,INDE4)
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,MXLOW,R,IOUT,INDE4)
      CALL URWORD(LINE,LLOC,ISTART,ISTOP,2,MXBW,R,IOUT,INDE4)
      IF(ITMX.LT.1) ITMX=1
      WRITE(IOUT,3) ITMX
    3 FORMAT(1X,'MAXIMUM ITERATIONS (EXTERNAL OR INTERNAL) =',I3)
      IF(MXUP.LT.1) MXUP=NHALFU
      IF(MXLOW.LT.1) MXLOW=NHALFL
      MXEQ=MXUP+MXLOW
      IF(MXBW.LT.1) MXBW=NBWGRD
      WRITE(IOUT,4) MXUP,MXLOW,MXBW
    4 FORMAT(1X,'MAXIMUM EQUATIONS IN UPPER PART OF [A]:',I7,/
     1       1X,'MAXIMUM EQUATIONS IN LOWER PART OF [A]:',I7,/
     2       1X,'MAXIMUM BAND WIDTH OF [AL] PLUS 1:',I5)
C
C4------ALLOCATE SPACE FOR THE DE4 ARRAYS.
      ALLOCATE (AU(ID4DIM,MXUP))
      ALLOCATE (IUPPNT(ID4DIM,MXUP))
      ALLOCATE (AL(MXBW,MXLOW))
      ALLOCATE (IEQPNT(NCOL,NROW,NLAY))
      ALLOCATE (D4B(MXEQ))
      ALLOCATE (LRCHDE4(3,ITMX))
      ALLOCATE (HDCGDE4(ITMX))
C
C1------READ IFREQ, MUTD4, ACCL, HCLOSE, AND IPRD4
      ONE=1.
      ZERO=0.
      READ(INDE4,*) IFREQ,MUTD4,ACCLDE4,HCLOSEDE4,IPRD4
      IF(ACCLDE4.LE.ZERO) ACCLDE4=ONE
      IF(IPRD4.LE.0) IPRD4=999
      IF(MUTD4.LT.0 .OR. MUTD4.GT.3) MUTD4=0
      IF(IFREQ.LT.1 .OR. IFREQ.GT.3) THEN
         WRITE(IOUT,11) IFREQ
   11    FORMAT(1X,/1X,'INVALID VALUE FOR IFREQ PARAMETER:',I8)
         CALL USTOP(' ')
      END IF
C
C2------CHECK TO SEE IF THERE IS ITERATION (ITMX>1).
      IF(ITMX.GT.1) THEN
C
C3------THERE IS ITERATION -- DETERMINE TYPE OF ITERATION BASED ON IFREG
C3------VALUE.
         IF(IFREQ.EQ.3) THEN
C
C3A-----EXTERNAL ITERATION -- SET ITERATION VARIABLES AND PRINT A
C3A-----MESSAGE.
            MXITER=ITMX
            NITERDE4=1
            WRITE(IOUT,51)
   51       FORMAT(1X,/21X,'SOLUTION BY D4 DIRECT SOLVER WITH EXTERNAL',
     1       ' ITERATION',/21X,52('-'),/)
C
C3B-----INTERNAL ITERATION -- SET ITERATION VARIABLES AND PRINT A
C3B-----MESSAGE.
         ELSE
            MXITER=1
            NITERDE4=ITMX
            WRITE(IOUT,81)
   81       FORMAT(1X,/21X,'SOLUTION BY D4 DIRECT SOLVER WITH INTERNAL',
     1       ' ITERATION'/21X,52('-')/)
         END IF
C
C3C-----PRINT ITERATION INFORMATION.
         WRITE(IOUT,91) ITMX,ACCLDE4,HCLOSEDE4,IPRD4
   91    FORMAT(1X,'MAXIMUM ITERATIONS =',I3/
     1       1X,'RELAXATION-ACCELERATION PARAMETER =',F10.6/
     2       1X,'HEAD CHANGE CRITERION FOR CLOSURE =',G15.5/
     3       1X,'D4 PRINTOUT INTERVAL =',I4)
         IF(MUTD4.EQ.1) WRITE(IOUT,92)
   92    FORMAT(1X,
     1   'CONVERGENCE PRINTOUT WILL SHOW ONLY THE NUMBER OF ITERATIONS')
         IF(MUTD4.EQ.2) WRITE(IOUT,93)
   93    FORMAT(1X,'CONVERGENCE PRINTOUT WILL BE SUPPRESSED')
C
C4------NO ITERATION -- SET ITERATION VARIABLES AND PRINT A MESSAGE.
      ELSE
         MXITER=1
         NITERDE4=1
         ACCLDE4=ONE
         WRITE(IOUT,94)
   94    FORMAT(1X,/21X,
     1   'SOLUTION BY D4 DIRECT SOLVER WITH NO ITERATION',/21X,46('-')/)
         IF(MUTD4.EQ.2) WRITE(IOUT,95)
   95    FORMAT(1X,'PRINTOUT OF MAXIMUM HEAD CHANGE WILL BE SUPPRESSED')
      END IF
C
C5------PRINT MESSAGE ABOUT FREQUENCY AT WHICH [A] IS ELIMINATED.
      IF(IFREQ.EQ.3) WRITE(IOUT,102)
  102 FORMAT(1X,'NON-LINEAR PROBLEM -- [A] MATRIX ELIMINATED',
     1   ' EVERY TIME EQUATIONS ARE REFORMULATED')
      IF(IFREQ.NE.3) WRITE(IOUT,103) IFREQ
  103 FORMAT(1X,'LINEAR PROBLEM -- [A] MATRIX ELIMINATED ONLY',
     1   ' WHEN IT CHANGES -- IFREQ=',I1)
C
C6------RETURN.
      CALL DE47PSV(IGRID)
      RETURN
      END
      SUBROUTINE DE47AP(HNEW,IBOUND,AU,AL,IUPPNT,IEQPNT,D4B,MXUP,MXLOW,
     1  MXEQ,MXBW,CR,CC,CV,HCOF,RHS,ACCLDE4,KITER,ITMX,MXITER,NITERDE4,
     2  HCLOSEDE4,IPRD4,ICNVG,NCOL,NROW,NLAY,IOUT,LRCHDE4,HDCGDE4,
     3  IFREQ,KSTP,KPER,DELT,NSTP,ID4DIR,ID4DIM,MUTD4,DELTL,NBWL,NUPL,
     4  NLOWL,NLOW,NEQ,NUP,NBW,IERR)
C     ******************************************************************
C     SOLVE FINITE-DIFFERENCE EQUATIONS FOR ONE EXTERNAL ITERATION.
C     MULTIPLE SOLUTIONS ARE MADE WHEN INTERNALLY ITERATING.
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DIMENSION HNEW(NCOL,NROW,NLAY),AU(ID4DIM,MXUP),AL(MXBW,MXLOW),
     1          IEQPNT(NCOL,NROW,NLAY),IUPPNT(ID4DIM,MXUP),D4B(MXEQ),
     2          CR(NCOL,NROW,NLAY),CC(NCOL,NROW,NLAY),
     3          CV(NCOL,NROW,NLAY),HCOF(NCOL,NROW,NLAY),
     4          RHS(NCOL,NROW,NLAY),IBOUND(NCOL,NROW,NLAY),
     5          LRCHDE4(3,ITMX),HDCGDE4(ITMX)
C
      DOUBLE PRECISION HNEW,EE,COND,RR,DDH,RHS,HCOF
C
      DIMENSION CND(6),IEQ(6),IDIR(6,6)
C      SAVE DELTL,NBWL,NUPL,NLOWL,NLOW,NEQ,NUP,NBW
      DATA IDIR/1,2,3,4,5,6,
     1          2,1,3,4,6,5,
     2          1,3,2,5,4,6,
     3          3,1,2,5,6,4,
     4          2,3,1,6,4,5,
     5          3,2,1,6,5,4/
C
C      DATA DELTL,NBWL,NUPL,NLOWL/0.,0,0,0/
C     ------------------------------------------------------------------
C
C1------INITIALIZE VARIABLES AND SET FLAG THAT INDICATES IF [A] REQUIRES
C1------ELIMINATION.
      ZERO=0.
      ICNVG=0
      NIT=0
      ITYPE=0
      IF(IFREQ.EQ.0) THEN
         ITYPE=1
      ELSE IF(IFREQ.EQ.2) THEN
         IF(KSTP.NE.1 .AND. DELT.EQ.DELTL) ITYPE=1
      ELSE IF(IFREQ.EQ.1) THEN
         IF((KPER.NE.1 .OR. KSTP.NE.1) .AND. DELT.EQ.DELTL) ITYPE=1
      END IF
      DELTL=DELT
C
C2------DO ONE INTERNAL ITERATION.
   10 NIT=NIT+1
      BIGA=ZERO
      BIG=ZERO
      IBIG=0
      JBIG=0
      KBIG=0
C
C3------GO TO STATEMENT 100 IF [A] DOES NOT REQUIRE ELIMINATION.
      IF (ITYPE.EQ.1) GO TO 100
C
C4------[A] REQUIRES ELIMINATION.
C4A-----CALL MODULE SDE47N TO ORDER EQUATIONS.  IF MXUP OR MXLOW ARE
C4A-----TOO SMALL, PRINT A MESSAGE AND STOP.
      CALL SDE47N(IEQPNT,IBOUND,NCOL,NROW,NLAY,ID4DIR,NUP,NLOW,NEQ)
      IF(NUP.GT.MXUP .OR. NLOW.GT.MXLOW) THEN
         WRITE(IOUT,41) NUP,NLOW
   41    FORMAT(1X,'INSUFFICIENT MEMORY FOR DE4 SOLVER:',/
     1          1X,'MXUP MUST BE AT LEAST',I8,/
     1          1X,'MXLOW MUST BE AT LEAST',I8)
         IERR = 1
         RETURN
      END IF
C
C4B-----INITIALIZE AU.
      DO 50 I=1,NUP
      DO 50 J=2,ID4DIM
      AU(J,I)=ZERO
   50 CONTINUE
C
C5------LOOP THROUGH ALL CELLS CALCULATING COEFFICIENTS AND LOADING
C5------ARRAYS FOR SOLUTION.  THE RESIDUAL MUST ALWAYS BE CALCULATED
C5------AND LOADED IN D4B; IUPPNT, AU, AND AL(1,n) ARE CALCULATED AND
C5------LOADED ONLY IF [A] REQUIRES ELIMINATION.
  100 DO 310 K=1,NLAY
      DO 310 I=1,NROW
      DO 310 J=1,NCOL
      IR=IEQPNT(J,I,K)
      IF(IR.EQ.0) GO TO 310
C
C5A-----CALCULATE AND LOAD D4B.
      DO 110 N=1,6
      IEQ(N)=0
  110 CONTINUE
      RR=RHS(J,I,K)
      EE=HCOF(J,I,K)
      IF(J.NE.1) THEN
         CLF=CR(J-1,I,K)
         COND=CLF
         RR=RR-COND*HNEW(J-1,I,K)
         EE=EE-COND
         CND(1)=CLF
         IEQ(1)=IEQPNT(J-1,I,K)
      END IF
      IF(I.NE.1) THEN
         CBK=CC(J,I-1,K)
         COND=CBK
         RR=RR-COND*HNEW(J,I-1,K)
         EE=EE-COND
         CND(2)=CBK
         IEQ(2)=IEQPNT(J,I-1,K)
      END IF
      IF(K.NE.1) THEN
         CUP=CV(J,I,K-1)
         COND=CUP
         RR=RR-COND*HNEW(J,I,K-1)
         EE=EE-COND
         CND(3)=CUP
         IEQ(3)=IEQPNT(J,I,K-1)
      END IF
      IF(K.NE.NLAY) THEN
         CDN=CV(J,I,K)
         COND=CDN
         RR=RR-COND*HNEW(J,I,K+1)
         EE=EE-COND
         CND(4)=CDN
         IEQ(4)=IEQPNT(J,I,K+1)
      END IF
      IF(I.NE.NROW) THEN
         CFR=CC(J,I,K)
         COND=CFR
         RR=RR-COND*HNEW(J,I+1,K)
         EE=EE-COND
         CND(5)=CFR
         IEQ(5)=IEQPNT(J,I+1,K)
      END IF
      IF(J.NE.NCOL) THEN
         CRT=CR(J,I,K)
         COND=CRT
         RR=RR-COND*HNEW(J+1,I,K)
         EE=EE-COND
         CND(6)=CRT
         IEQ(6)=IEQPNT(J+1,I,K)
      END IF
      D4B(IR)=RR-EE*HNEW(J,I,K)
C
C5B-----IF [A] REQUIRES ELIMINATION, LOAD AL(1,N) AND AU
      IF (ITYPE.EQ.1) GO TO 310
      IF (IR.GT.NUP) THEN
         IRR=IR-NUP
         AL(1,IRR)=EE
      ELSE
         N=1
         DO 305 II=1,6
            M=IDIR(II,ID4DIR)
            L=IEQ(M)
            IF(L.NE.0) THEN
               N=N+1
               IUPPNT(N,IR)=L
               AU(N,IR)=CND(M)
            END IF
  305    CONTINUE
         AU(1,IR)=EE
         IUPPNT(1,IR)=N
      END IF
  310 CONTINUE
C
C6------IF [A] DOES NOT REQUIRE ELIMINATION, SKIP TO STATEMENT 380.
      IF(ITYPE.EQ.1) GO TO 380
C6A-----[A] REQUIRES ELIMINATION -- DETERMINE BAND WIDTH + 1.
      MNN=999999
      MXN=0
      DO 350 I=1,NUP
      L=IUPPNT(1,I)
      IF(L.LT.2) GO TO 350
      N=IUPPNT(2,I)-I
      IF(N.LT.MNN) MNN=N
      N=IUPPNT(L,I)-I
      IF(N.GT.MXN) MXN=N
  350 CONTINUE
      NBW=MXN-MNN+1
C
C6B-----WRITE BAND WIDTH + 1 AND NUMBER OF EQUATIONS IF ANY HAVE CHANGED.
      IF(NUP.NE.NUPL .OR. NLOW.NE.NLOWL .OR. NBW.NE.NBWL) THEN
         WRITE(IOUT,351) NUP,NLOW,NBW
  351    FORMAT(1X,/1X,I7,' UPPER PART EQS.',
     1     I10,' LOWER PART EQS.    BAND WIDTH + 1 =',I5)
         NUPL=NUP
         NLOWL=NLOW
         NBWL=NBW
      END IF
C
C6C-------STOP IF BAND WIDTH EXCEEDS USER-SPECIFIED SIZE.
      IF(NBW.GT.MXBW) THEN
         WRITE(IOUT,353) NBW
  353    FORMAT(1X,'INSUFFICIENT MEMORY FOR DE4 SOLVER:',/
     1          1X,'MXBW MUST BE AT LEAST',I5)
         IERR = 1
         RETURN
      END IF
C
C6D-------INITIALIZE OFF DIAGONAL PART OF AL.
      DO 360 I=1,NLOW
      DO 360 J=2,NBW
      AL(J,I)=ZERO
  360 CONTINUE
C
C7------CALL MODULE SDE47S TO SOLVE EQUATIONS FOR HEAD CHANGE.
  380 CALL SDE47S(AU,AL,IUPPNT,D4B,NUP,NLOW,NEQ,MXBW,NBW,ITYPE,ID4DIM)
C
C8------CALCULATE NEW HEAD FROM HEAD CHANGE AND FIND MAXIMUM CHANGE.
      DO 400 K=1,NLAY
      DO 400 I=1,NROW
      DO 400 J=1,NCOL
      L=IEQPNT(J,I,K)
      IF(L.EQ.0) GO TO 400
      DH=ACCLDE4*D4B(L)
      TCHK=ABS(DH)
      IF(TCHK.GT.BIGA) THEN
         BIGA=TCHK
         BIG=DH
         IBIG=I
         JBIG=J
         KBIG=K
      END IF
      DDH=DH
      HNEW(J,I,K)=HNEW(J,I,K)+DDH
  400 CONTINUE
C
C9------IF THE NUMBER OF INTERNAL ITERATIONS IS 1, GO TO STATEMENT 500
      IF(NITERDE4.EQ.1) GO TO 500
C
C10-----THE NUMBER OF INTERNAL ITERATIONS IS GREATER THAN 1, SO MUST BE
C10-----ITERATING INTERNALLY.  KEEP TRACK OF MAXIMUM HEAD CHANGE AND
C10-----CHECK FOR CONVERGENCE.
      LRCHDE4(1,NIT)=KBIG
      LRCHDE4(2,NIT)=IBIG
      LRCHDE4(3,NIT)=JBIG
      HDCGDE4(NIT)=BIG
      IF(ABS(BIG).LE.HCLOSEDE4) ICNVG=1
C
C10A----IF NOT CONVERGED AND MAXIMUM ITERATIONS HAS NOT BEEN REACHED,
C10A----GO BACK AND DO ANOTHER INTERNAL ITERATION.  SET ITYPE=1 TO
C10A----AVOID REFORMULATION OF [A].
      ITYPE=1
      IF(ICNVG.EQ.0 .AND. NIT.NE.NITERDE4) GO TO 10
C
C10B----INTERNAL ITERATION IS DONE EITHER BECAUSE CONVERGENCE IS REACHED
C10B----OR BECAUSE MAX. ITERATIONS EXCEEDED.  PRINT CONVERGENCE
C10B----INFORMATION UNLESS IMUTD4=2.
      IF(MUTD4.LT.2) THEN
C10B1---PRINT A BLANK LINE IF THIS IS THE FIRST TIME STEP.
         IF(KSTP.EQ.1) WRITE(IOUT,601)
C10B2---PRINT NUMBER OF ITERATIONS.
         WRITE(IOUT,751) NIT,KSTP,KPER
  751    FORMAT(1X,I5,' INTERNAL ITERATIONS FOR TIME STEP',I4,
     1        ' IN STRESS PERIOD ',I4)
C10B3---IF MUTD4=0 AND
C10B3---IF FAILED TO CONVERGE OR LAST TIME STEP IN STRESS PERIOD OR
C10B3---IPRD4 INTERVAL IS MET, CALL MODULE SDE47P TO PRINT HEAD CHANGE.
         IF((MUTD4.EQ.0) .AND.
     1      (ICNVG.EQ.0 .OR. KSTP.EQ.NSTP .OR. MOD(KSTP,IPRD4).EQ.0))
     2         CALL SDE47P(HDCGDE4,LRCHDE4,NIT,IOUT,NCOL,NROW)
      ELSE IF(MUTD4.EQ.3 .AND. ICNVG.EQ.0) THEN
         CALL SDE47P(HDCGDE4,LRCHDE4,NIT,IOUT,NCOL,NROW)
      END IF
C10B4---RETURN.
      RETURN
C
C11-----THERE ARE NO INTERNAL ITERATIONS, SO THERE MUST EITHER BE
C11-----EXTERNAL ITERATION OR NO ITERATION.  IF THERE IS EXTERNAL
C11-----ITERATION, GO TO STATEMENT 600.
  500 IF(MXITER.NE.1) GO TO 600
C
C12-----NO ITERATION (NITERDE4=1 AND MXITER=1).  SET FLAG TO INDICATE
C12-----CONVERGENCE HAS OCCURRED, AND PRINT MAXIMUM HEAD CHANGE UNLESS
C12-----MUTD4<2.
      ICNVG=1
      IF(MUTD4.LT.2) WRITE(IOUT,501) KSTP,KPER,BIG,KBIG,IBIG,JBIG
  501 FORMAT(1X,/1X,'MAXIMUM HEAD CHANGE IN TIME STEP ',I3,
     1      ' OF STRESS PERIOD ',I4,' =',G15.5,
     2      ' AT LAYER =',I3,', ROW =',I5,', COL=',I5)
      RETURN
C
C13-----EXTERNAL ITERATION.  KEEP TRACK OF MAXIMUM HEAD CHANGE AND SET
C13-----CONVERGENCE FLAG IF CONVERGENCE OCCURRED.
  600 LRCHDE4(1,KITER)=KBIG
      LRCHDE4(2,KITER)=IBIG
      LRCHDE4(3,KITER)=JBIG
      HDCGDE4(KITER)=BIG
      IF(ABS(BIG).LE.HCLOSEDE4) ICNVG=1
C13A----RETURN IF NO CONVERGENCE AND MAX. ITERATIONS NOT EXCEEDED.
      IF(ICNVG.EQ.0 .AND. KITER.NE.MXITER) RETURN
C13B----EXTERNAL ITERATION IS DONE EITHER BECAUSE CONVERGENCE IS REACHED
C13B----OR BECAUSE MAX. ITERATIONS EXCEEDED.  PRINT CONVERGENCE
C13B----INFORMATION UNLESS IMUTD4=2.
      IF(MUTD4.LT.2) THEN
C13B1---PRINT A BLANK LINE IF THIS IS THE FIRST TIME STEP.
         IF(KSTP.EQ.1) WRITE(IOUT,601)
  601    FORMAT(1X)
C13B2---PRINT NUMBER OF ITERATIONS.
         WRITE(IOUT,602) KITER,KSTP,KPER
  602    FORMAT(1X,I5,' EXTERNAL ITERATIONS FOR TIME STEP',I4,
     1        ' IN STRESS PERIOD ',I4)
C13B3---IF MUTD4=0 AND
C13B3---IF FAILED TO CONVERGE OR LAST TIME STEP IN STRESS PERIOD OR
C13B3---IPRD4 INTERVAL IS MET, CALL MODULE SDE47P TO PRINT HEAD CHANGE.
         IF((MUTD4.EQ.0) .AND.
     1      (ICNVG.EQ.0 .OR. KSTP.EQ.NSTP .OR. MOD(KSTP,IPRD4).EQ.0))
     2         CALL SDE47P(HDCGDE4,LRCHDE4,KITER,IOUT,NCOL,NROW)
      ELSE IF(MUTD4.EQ.3 .AND. ICNVG.EQ.0) THEN
         CALL SDE47P(HDCGDE4,LRCHDE4,KITER,IOUT,NCOL,NROW)
      END IF
C13B4---Return.
      RETURN
C
      END
      SUBROUTINE SDE47N(IEQPNT,IBOUND,NCOL,NROW,NLAY,ID4DIR,NUP,NLOW,
     1          NEQ)
C     ******************************************************************
C     ORDER EQUATIONS USING D4 ORDERING
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DIMENSION IEQPNT(NCOL,NROW,NLAY), IBOUND(NCOL,NROW,NLAY)
C     ------------------------------------------------------------------
C
C1------CALCULATE MAXIMUM PLANE NUMBER AND INITIALIZE EQUATION POINTERS.
      NPLANE=NCOL+NROW+NLAY
      DO 20 K=1,NLAY
      DO 20 I=1,NROW
      DO 20 J=1,NCOL
      IEQPNT(J,I,K)=0
   20 CONTINUE
      NEQ=0
C
C2------ORDER EQUATIONS BASED ON DIRECTION FLAG, ID4DIR
C2------Ordering is done as described by Price, H.S. and Coats, K.H.,
C2------1974,Direct methods in reservoir simulation: Soc. Petrol. Eng.
C2------Jour., June 1974, p. 295-308.
      GO TO (100,200,300,400,500,600) ID4DIR
      CALL USTOP(' ')
C
C3------DIRECTION 1 -- NCOL>or=NROW>or=NLAY
C3A-----Order equations with odd plane numbers.
  100 DO 130 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NLAY) K1=NLAY
      K2=N-NCOL-NROW
      IF(K2.LT.1) K2=1
      DO 130 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NROW) I1=NROW
      I2=N-K-NCOL
      IF(I2.LT.1) I2=1
      DO 130 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(J,I,K).LE.0) GO TO 130
      NEQ=NEQ+1
      IEQPNT(J,I,K)=NEQ
  130 CONTINUE
      NUP=NEQ
C
C3B-----Order equations with even plane numbers.
      DO 140 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NLAY) K1=NLAY
      K2=N-NCOL-NROW
      IF(K2.LT.1) K2=1
      DO 140 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NROW) I1=NROW
      I2=N-K-NCOL
      IF(I2.LT.1) I2=1
      DO 140 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(J,I,K).LE.0) GO TO 140
      NEQ=NEQ+1
      IEQPNT(J,I,K)=NEQ
  140 CONTINUE
      NLOW=NEQ-NUP
      IF ( NLOW.LT.1 ) NLOW = 1  !JDH 20110814
      RETURN
C
C4------DIRECTION 2 NROW>NCOL>or=NLAY
C4A-----Order equations with odd plane numbers.
  200 DO 230 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NLAY) K1=NLAY
      K2=N-NCOL-NROW
      IF(K2.LT.1) K2=1
      DO 230 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NCOL) I1=NCOL
      I2=N-K-NROW
      IF(I2.LT.1) I2=1
      DO 230 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(I,J,K).LE.0) GO TO 230
      NEQ=NEQ+1
      IEQPNT(I,J,K)=NEQ
  230 CONTINUE
      NUP=NEQ
C
C4B-----Order equations with even plane numbers.
      DO 240 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NLAY) K1=NLAY
      K2=N-NCOL-NROW
      IF(K2.LT.1) K2=1
      DO 240 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NCOL) I1=NCOL
      I2=N-K-NROW
      IF(I2.LT.1) I2=1
      DO 240 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(I,J,K).LE.0) GO TO 240
      NEQ=NEQ+1
      IEQPNT(I,J,K)=NEQ
  240 CONTINUE
      NLOW=NEQ-NUP
      RETURN
C
C-------DIRECTION 3 NCOL>or=NLAY>NROW
C5A-----Order equations with odd plane numbers.
  300 DO 330 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NROW) K1=NROW
      K2=N-NCOL-NLAY
      IF(K2.LT.1) K2=1
      DO 330 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NLAY) I1=NLAY
      I2=N-K-NCOL
      IF(I2.LT.1) I2=1
      DO 330 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(J,K,I).LE.0) GO TO 330
      NEQ=NEQ+1
      IEQPNT(J,K,I)=NEQ
  330 CONTINUE
      NUP=NEQ
C
C5B-----Order equations with even plane numbers.
      DO 340 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NROW) K1=NROW
      K2=N-NCOL-NLAY
      IF(K2.LT.1) K2=1
      DO 340 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NLAY) I1=NLAY
      I2=N-K-NCOL
      IF(I2.LT.1) I2=1
      DO 340 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(J,K,I).LE.0) GO TO 340
      NEQ=NEQ+1
      IEQPNT(J,K,I)=NEQ
  340 CONTINUE
      NLOW=NEQ-NUP
      RETURN
C
C6------DIRECTION 4 NLAY>NCOL>or=NROW
C6A-----Order equations with odd plane numbers.
  400 DO 430 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NROW) K1=NROW
      K2=N-NCOL-NLAY
      IF(K2.LT.1) K2=1
      DO 430 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NCOL) I1=NCOL
      I2=N-K-NLAY
      IF(I2.LT.1) I2=1
      DO 430 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(I,K,J).LE.0) GO TO 430
      NEQ=NEQ+1
      IEQPNT(I,K,J)=NEQ
  430 CONTINUE
      NUP=NEQ
C
C6B-----Order equations with even plane numbers.
      DO 440 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NROW) K1=NROW
      K2=N-NCOL-NLAY
      IF(K2.LT.1) K2=1
      DO 440 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NCOL) I1=NCOL
      I2=N-K-NLAY
      IF(I2.LT.1) I2=1
      DO 440 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(I,K,J).LE.0) GO TO 440
      NEQ=NEQ+1
      IEQPNT(I,K,J)=NEQ
  440 CONTINUE
      NLOW=NEQ-NUP
      RETURN
C
C7------DIRECTION 5 NROW>or=NLAY>NCOL
C7A-----Order equations with odd plane numbers.
  500 DO 530 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NCOL) K1=NCOL
      K2=N-NROW-NLAY
      IF(K2.LT.1) K2=1
      DO 530 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NLAY) I1=NLAY
      I2=N-K-NROW
      IF(I2.LT.1) I2=1
      DO 530 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(K,J,I).LE.0) GO TO 530
      NEQ=NEQ+1
      IEQPNT(K,J,I)=NEQ
  530 CONTINUE
      NUP=NEQ
C
C7B-----Order equations with even plane numbers.
      DO 540 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NCOL) K1=NCOL
      K2=N-NROW-NLAY
      IF(K2.LT.1) K2=1
      DO 540 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NLAY) I1=NLAY
      I2=N-K-NROW
      IF(I2.LT.1) I2=1
      DO 540 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(K,J,I).LE.0) GO TO 540
      NEQ=NEQ+1
      IEQPNT(K,J,I)=NEQ
  540 CONTINUE
      NLOW=NEQ-NUP
      RETURN
C
C-------DIRECTION 6 NLAY>NROW>NCOL
C8A-----Order equations with odd plane numbers.
  600 DO 630 N=3,NPLANE,2
      K1=N-2
      IF(K1.GT.NCOL) K1=NCOL
      K2=N-NROW-NLAY
      IF(K2.LT.1) K2=1
      DO 630 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NROW) I1=NROW
      I2=N-K-NLAY
      IF(I2.LT.1) I2=1
      DO 630 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(K,I,J).LE.0) GO TO 630
      NEQ=NEQ+1
      IEQPNT(K,I,J)=NEQ
  630 CONTINUE
      NUP=NEQ
C
C8B-----Order equations with even plane numbers.
      DO 640 N=4,NPLANE,2
      K1=N-2
      IF(K1.GT.NCOL) K1=NCOL
      K2=N-NROW-NLAY
      IF(K2.LT.1) K2=1
      DO 640 K=K1,K2,-1
      I1=N-K-1
      IF(I1.GT.NROW) I1=NROW
      I2=N-K-NLAY
      IF(I2.LT.1) I2=1
      DO 640 I=I1,I2,-1
      J=N-K-I
      IF(IBOUND(K,I,J).LE.0) GO TO 640
      NEQ=NEQ+1
      IEQPNT(K,I,J)=NEQ
  640 CONTINUE
      NLOW=NEQ-NUP
      RETURN
C
      END
      SUBROUTINE SDE47S(AU,AL,IUPPNT,D4B,NUP,NLOW,NEQ,MXBW,NBW,ITYPE,
     1              ID4DIM)
C     ******************************************************************
C     SOLVE EQUATIONS USING GAUSS ELIMINATION ASSUMING D4 ORDERING
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DIMENSION AU(ID4DIM,NUP),AL(MXBW,NLOW),IUPPNT(ID4DIM,NUP),D4B(NEQ)
C     ------------------------------------------------------------------
C
C1------DEFINE CONSTANTS.
      ONE=1.
      ZERO=0.
      NLOWM1=NLOW-1
C
C2------DON'T ELIMINATE UNLESS NECESSARY.
      IF (ITYPE.EQ.1) GO TO 80
C
C2A-----MUST ELIMINATE -- DO THIS IN TWO PARTS.
C2A-----ELIMINATE THE LEFT SIDE OF THE LOWER PART OF [A] TO FILL [AL].
      DO 40 I=1,NUP
      JJ=IUPPNT(1,I)
      C1=ONE/AU(1,I)
      DO 30 J=2,JJ
      LR=IUPPNT(J,I)
      L=LR-NUP
      C=AU(J,I)*C1
      DO 20 K=J,JJ
      KL=IUPPNT(K,I)-LR+1
      AL(KL,L)=AL(KL,L)-C*AU(K,I)
   20 CONTINUE
      AU(J,I)=C
   30 CONTINUE
   40 CONTINUE
C
C2B-----ELIMINATE [AL].
      DO 70 I=1,NLOWM1
      L=I
      C1=ONE/AL(1,I)
      DO 60 J=2,NBW
      L=L+1
      IF (AL(J,I).EQ.ZERO) GO TO 60
      C=AL(J,I)*C1
      KL=0
      DO 50 K=J,NBW
      KL=KL+1
      IF (AL(K,I).NE.ZERO) AL(KL,L)=AL(KL,L)-C*AL(K,I)
   50 CONTINUE
      AL(J,I)=C
   60 CONTINUE
   70 CONTINUE
C
C3------D4B MUST ALWAYS BE MODIFIED -- MODIFY D4B IN TWO PARTS.
C3A-----MODIFY D4B DUE TO ELIMINATION TO FILL [AL].
   80 DO 100 I=1,NUP
      JJ=IUPPNT(1,I)
      DO 90 J=2,JJ
      LR=IUPPNT(J,I)
      D4B(LR)=D4B(LR)-AU(J,I)*D4B(I)
   90 CONTINUE
      D4B(I)=D4B(I)/AU(1,I)
  100 CONTINUE
C
C3B-----MODIFY D4B DUE TO ELIMINATION OF [AL].
      DO 120 I=1,NLOWM1
      IR=I+NUP
      LR=IR
      DO 110 J=2,NBW
      LR=LR+1
      IF (AL(J,I).NE.ZERO) D4B(LR)=D4B(LR)-AL(J,I)*D4B(IR)
  110 CONTINUE
      D4B(IR)=D4B(IR)/AL(1,I)
  120 CONTINUE
C
C4------BACK SUBSTITUTE LOWER PART.
!      D4B(NEQ)=D4B(NEQ)/AL(1,NEQ-NUP)
      IJDH = NEQ-NUP                  !JDH 20110814
      IF ( IJDH.LT.1 ) THEN           !JDH 20110814
        IJDH = 1                      !JDH 20110814
      END IF                          !JDH 20110814
      D4B(NEQ)=D4B(NEQ)/AL(1,IJDH)    !JDH 20110814
      DO 140 I=1,NLOWM1
      K=NEQ-I
      KL=K-NUP
      L=K
      DO 130 J=2,NBW
      L=L+1
      IF (AL(J,KL).NE.ZERO) D4B(K)=D4B(K)-AL(J,KL)*D4B(L)
  130 CONTINUE
  140 CONTINUE
C
C5------BACK SUBSTITUTE UPPER PART.
      DO 160 I=1,NUP
      K=NUP+1-I
      JJ=IUPPNT(1,K)
      DO 150 J=2,JJ
      L=IUPPNT(J,K)
      D4B(K)=D4B(K)-AU(J,K)*D4B(L)
  150 CONTINUE
  160 CONTINUE
C
C6------RETURN.
      RETURN
      END
      SUBROUTINE SDE47P(HDCGDE4,LRCHDE4,NUMIT,IOUT,NCOL,NROW)
C     ******************************************************************
C     PRINT MAXIMUM HEAD CHANGE DURING EACH D4 ITERATION FOR A TIME STEP
C     ******************************************************************
C
C        SPECIFICATIONS:
C     ------------------------------------------------------------------
      DIMENSION HDCGDE4(NUMIT), LRCHDE4(3,NUMIT)
C     ------------------------------------------------------------------
C
      IF (NCOL.LE.999 .AND. NROW.LE.999) THEN
        WRITE(IOUT,5)
    5   FORMAT(1X,/1X,'MAXIMUM HEAD CHANGE FOR EACH ITERATION:',/
     1    1X,/1X,3('  HEAD CHANGE  LAY,ROW,COL'),/1X,79('-'))
        WRITE (IOUT,10) (HDCGDE4(J),(LRCHDE4(I,J),I=1,3),J=1,NUMIT)
   10   FORMAT((2X,3(2X,1PG10.3,' (',I3,',',I3,',',I3,')')))
      ELSE
        WRITE(IOUT,15)
   15   FORMAT(1X,/1X,'MAXIMUM HEAD CHANGE FOR EACH ITERATION:',/
     1    1X,/1X,2('    HEAD CHANGE  LAY,ROW,COL  '),/1X,60('-'))
        WRITE (IOUT,20) (HDCGDE4(J),(LRCHDE4(I,J),I=1,3),J=1,NUMIT)
   20   FORMAT((2X,2(2X,1PG10.3,' (',I3,',',I5,',',I5,')')))
      ENDIF
      WRITE(IOUT,30)
   30 FORMAT(1X,/1X)
C
      RETURN
      END
      SUBROUTINE DE47DA(IGRID)
C  Deallocate DE4 data
      USE DE4MODULE
C
      DEALLOCATE(DE4DAT(IGRID)%MXUP)
      DEALLOCATE(DE4DAT(IGRID)%MXLOW)
      DEALLOCATE(DE4DAT(IGRID)%MXEQ)
      DEALLOCATE(DE4DAT(IGRID)%MXBW)
      DEALLOCATE(DE4DAT(IGRID)%ITMX)
      DEALLOCATE(DE4DAT(IGRID)%ID4DIR)
      DEALLOCATE(DE4DAT(IGRID)%NITERDE4)
      DEALLOCATE(DE4DAT(IGRID)%IFREQ)
      DEALLOCATE(DE4DAT(IGRID)%IPRD4)
      DEALLOCATE(DE4DAT(IGRID)%MUTD4)
      DEALLOCATE(DE4DAT(IGRID)%ID4DIM)
      DEALLOCATE(DE4DAT(IGRID)%NBWL)
      DEALLOCATE(DE4DAT(IGRID)%NUPL)
      DEALLOCATE(DE4DAT(IGRID)%NLOWL)
      DEALLOCATE(DE4DAT(IGRID)%NLOW)
      DEALLOCATE(DE4DAT(IGRID)%NEQ)
      DEALLOCATE(DE4DAT(IGRID)%NUP)
      DEALLOCATE(DE4DAT(IGRID)%NBW)
      DEALLOCATE(DE4DAT(IGRID)%DELTL)
      DEALLOCATE(DE4DAT(IGRID)%ACCLDE4)
      DEALLOCATE(DE4DAT(IGRID)%HCLOSEDE4)
      DEALLOCATE(DE4DAT(IGRID)%IUPPNT)
      DEALLOCATE(DE4DAT(IGRID)%IEQPNT)
      DEALLOCATE(DE4DAT(IGRID)%AU)
      DEALLOCATE(DE4DAT(IGRID)%AL)
      DEALLOCATE(DE4DAT(IGRID)%D4B)
      DEALLOCATE(DE4DAT(IGRID)%HDCGDE4)
      DEALLOCATE(DE4DAT(IGRID)%LRCHDE4)
C
      RETURN
      END
      SUBROUTINE DE47PNT(IGRID)
C  Set pointers to DE4 data for grid.
      USE DE4MODULE
C
      MXUP=>DE4DAT(IGRID)%MXUP
      MXLOW=>DE4DAT(IGRID)%MXLOW
      MXEQ=>DE4DAT(IGRID)%MXEQ
      MXBW=>DE4DAT(IGRID)%MXBW
      ITMX=>DE4DAT(IGRID)%ITMX
      ID4DIR=>DE4DAT(IGRID)%ID4DIR
      NITERDE4=>DE4DAT(IGRID)%NITERDE4
      IFREQ=>DE4DAT(IGRID)%IFREQ
      IPRD4=>DE4DAT(IGRID)%IPRD4
      MUTD4=>DE4DAT(IGRID)%MUTD4
      ID4DIM=>DE4DAT(IGRID)%ID4DIM
      NBWL=>DE4DAT(IGRID)%NBWL 
      NUPL=>DE4DAT(IGRID)%NUPL 
      NLOWL=>DE4DAT(IGRID)%NLOWL 
      NLOW=>DE4DAT(IGRID)%NLOW 
      NEQ=>DE4DAT(IGRID)%NEQ 
      NUP=>DE4DAT(IGRID)%NUP 
      NBW=>DE4DAT(IGRID)%NBW 
      DELTL=>DE4DAT(IGRID)%DELTL
      ACCLDE4=>DE4DAT(IGRID)%ACCLDE4
      HCLOSEDE4=>DE4DAT(IGRID)%HCLOSEDE4
      IUPPNT=>DE4DAT(IGRID)%IUPPNT
      IEQPNT=>DE4DAT(IGRID)%IEQPNT
      AU=>DE4DAT(IGRID)%AU
      AL=>DE4DAT(IGRID)%AL
      D4B=>DE4DAT(IGRID)%D4B
      HDCGDE4=>DE4DAT(IGRID)%HDCGDE4
      LRCHDE4=>DE4DAT(IGRID)%LRCHDE4
C
      RETURN
      END
      SUBROUTINE DE47PSV(IGRID)
C  Save pointers to DE4 data.
      USE DE4MODULE
C
      DE4DAT(IGRID)%MXUP=>MXUP
      DE4DAT(IGRID)%MXLOW=>MXLOW
      DE4DAT(IGRID)%MXEQ=>MXEQ
      DE4DAT(IGRID)%MXBW=>MXBW
      DE4DAT(IGRID)%ITMX=>ITMX
      DE4DAT(IGRID)%ID4DIR=>ID4DIR
      DE4DAT(IGRID)%NITERDE4=>NITERDE4
      DE4DAT(IGRID)%IFREQ=>IFREQ
      DE4DAT(IGRID)%IPRD4=>IPRD4
      DE4DAT(IGRID)%MUTD4=>MUTD4
      DE4DAT(IGRID)%ID4DIM=>ID4DIM
      DE4DAT(IGRID)%NBWL=>NBWL
      DE4DAT(IGRID)%NUPL=>NUPL
      DE4DAT(IGRID)%NLOWL=>NLOWL
      DE4DAT(IGRID)%NLOW=>NLOW
      DE4DAT(IGRID)%NEQ=>NEQ
      DE4DAT(IGRID)%NUP=>NUP
      DE4DAT(IGRID)%NBW=>NBW
      DE4DAT(IGRID)%DELTL=>DELTL
      DE4DAT(IGRID)%ACCLDE4=>ACCLDE4
      DE4DAT(IGRID)%HCLOSEDE4=>HCLOSEDE4
      DE4DAT(IGRID)%IUPPNT=>IUPPNT
      DE4DAT(IGRID)%IEQPNT=>IEQPNT
      DE4DAT(IGRID)%AU=>AU
      DE4DAT(IGRID)%AL=>AL
      DE4DAT(IGRID)%D4B=>D4B
      DE4DAT(IGRID)%HDCGDE4=>HDCGDE4
      DE4DAT(IGRID)%LRCHDE4=>LRCHDE4
C
      RETURN
      END
