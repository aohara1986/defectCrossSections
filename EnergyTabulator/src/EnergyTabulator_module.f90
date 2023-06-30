module energyTabulatorMod
  
  use constants, only: dp, eVToHartree
  use miscUtilities, only: int2str
  use errorsAndMPI
  use mpi

  implicit none

  ! Global variables not passed as arguments:
  integer :: ikStart, ikEnd
    !! Start and end k-points for each process
  integer :: nkPerProc
    !! Number of k-points on each process


  ! Variables that should be passed as arguments
  integer :: iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
    !! Energy band bounds for initial and final state
  integer :: CBMorVBMBand
    !! Band of CBM (electron capture) or VBM (hole capture)
  integer :: nKPoints
    !! Number of k-points
  integer :: nSpins
    !! Number of spin channels
  integer :: refBand
    !! Band of WZP reference carrier

  real(kind=dp) :: eCorrectTot
    !! Total-energy correction, if any
  real(kind=dp) :: eCorrectEigF
    !! Correction to eigenvalue difference with final state, if any
  real(kind=dp) :: eCorrectEigRef
    !! Correction to eigenvalue difference with reference carrier, if any
  real(kind=dp) :: eTotInitInit
    !! Total energy of the relaxed initial charge
    !! state (initial positions)
  real(kind=dp) :: eTotFinalInit
    !! Total energy of the unrelaxed final charge
    !! state (initial positions)
  real(kind=dp) :: eTotFinalFinal
    !! Total energy of the relaxed final charge
    !! state (final positions)

  character(len=300) :: exportDirInitInit
    !! Path to export for initial charge state
    !! in the initial positions
  character(len=300) :: exportDirFinalInit
    !! Path to export for final charge state
    !! in the initial positions
  character(len=300) :: exportDirFinalFinal
    !! Path to export for final charge state
    !! in the final positions
  character(len=300) :: outputDir
    !! Path to store energy tables

  namelist /inputParams/ exportDirFinalFinal, exportDirFinalInit, exportDirInitInit, outputDir, &
                         eCorrectTot, eCorrectEigF, eCorrectEigRef, &
                         iBandIinit, iBandIfinal, iBandFinit, iBandFfinal, refBand, CBMorVBMBand


  contains

!----------------------------------------------------------------------------
  subroutine initialize(iBandIinit, iBandIfinal, iBandFinit, iBandFfinal, CBMorVBMBand, refBand, eCorrectTot, eCorrectEigF, eCorrectEigRef, &
        exportDirInitInit, exportDirFinalInit, exportDirFinalFinal, outputDir)
    !! Set the default values for input variables and start timer
    !!
    !! <h2>Walkthrough</h2>
    !!
    
    implicit none

    ! Input variables:
    !integer, intent(in) :: nProcs
      ! Number of processes


    ! Output variables:
    integer, intent(out) :: iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
      !! Energy band bounds for initial and final state
    integer, intent(out) :: CBMorVBMBand
      !! Band of CBM (electron capture) or VBM (hole capture)
    integer, intent(out) :: refBand
      !! Band of WZP reference carrier

    real(kind=dp), intent(out) :: eCorrectTot
      !! Total-energy correction, if any
    real(kind=dp), intent(out) :: eCorrectEigF
      !! Correction to eigenvalue difference with final state, if any
    real(kind=dp), intent(out) :: eCorrectEigRef
      !! Correction to eigenvalue difference with reference carrier, if any

    character(len=300), intent(out) :: exportDirInitInit
      !! Path to export for initial charge state
      !! in the initial positions
    character(len=300), intent(out) :: exportDirFinalInit
      !! Path to export for final charge state
      !! in the initial positions
    character(len=300), intent(out) :: exportDirFinalFinal
      !! Path to export for final charge state
      !! in the final positions
    character(len=300), intent(out) :: outputDir
      !! Path to store energy tables

    ! Local variables:
    character(len=8) :: cdate
      !! String for date
    character(len=10) :: ctime
      !! String for time


    iBandIinit  = -1
    iBandIfinal = -1
    iBandFinit  = -1
    iBandFfinal = -1
    refBand = -1
    CBMorVBMBand = -1

    eCorrectTot = 0.0_dp
    eCorrectEigF = 0.0_dp
    eCorrectEigRef = 0.0_dp

    exportDirInitInit = ''
    exportDirFinalInit = ''
    exportDirFinalFinal = ''
    outputDir = './'

    call date_and_time(cdate, ctime)

    if(ionode) then

      write(*, '(/5X,"Energy tabulator starts on ",A9," at ",A9)') &
             cdate, ctime

      write(*, '(/5X,"Parallel version (MPI), running on ",I5," processors")') nProcs


    endif

  end subroutine initialize

!----------------------------------------------------------------------------
  subroutine checkInitialization(iBandIinit, iBandIfinal, iBandFinit, iBandFfinal, CBMorVBMBand, refBand, eCorrectTot, eCorrectEigF, eCorrectEigRef, &
        exportDirInitInit, exportDirFinalInit, exportDirFinalFinal, outputDir)

    implicit none

    ! Input variables:
    integer, intent(in) :: iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
      !! Energy band bounds for initial and final state
    integer, intent(in) :: CBMorVBMBand
      !! Band of CBM (electron capture) or VBM (hole capture)
    integer, intent(in) :: refBand
      !! Band of WZP reference carrier

    real(kind=dp), intent(inout) :: eCorrectTot
      !! Total-energy correction, if any
    real(kind=dp), intent(inout) :: eCorrectEigF
      !! Correction to eigenvalue difference with final state, if any
    real(kind=dp), intent(inout) :: eCorrectEigRef
      !! Correction to eigenvalue difference with reference carrier, if any

    character(len=300), intent(in) :: exportDirInitInit
      !! Path to export for initial charge state
      !! in the initial positions
    character(len=300), intent(in) :: exportDirFinalInit
      !! Path to export for final charge state
      !! in the initial positions
    character(len=300), intent(in) :: exportDirFinalFinal
      !! Path to export for final charge state
      !! in the final positions
    character(len=300), intent(in) :: outputDir
      !! Path to store energy tables

    ! Local variables:
    logical :: abortExecution
      !! Whether or not to abort the execution


    abortExecution = checkIntInitialization('iBandIinit', iBandIinit, 1, int(1e9))
    abortExecution = checkIntInitialization('iBandIfinal', iBandIfinal, iBandIinit, int(1e9)) .or. abortExecution
    abortExecution = checkIntInitialization('iBandFinit', iBandFinit, 1, int(1e9)) .or. abortExecution
    abortExecution = checkIntInitialization('iBandFfinal', iBandFfinal, iBandFinit, int(1e9)) .or. abortExecution 
    abortExecution = checkIntInitialization('refBand', refBand, 1, int(1e9)) .or. abortExecution
    abortExecution = checkIntInitialization('CBMorVBMBand', CBMorVBMBand, 1, int(1e9)) .or. abortExecution

    write(*,'("eCorrectTot = ", f8.4, " (eV)")') eCorrectTot
    write(*,'("eCorrectEigF = ", f8.4, " (eV)")') eCorrectEigF
    write(*,'("eCorrectEigRef = ", f8.4, " (eV)")') eCorrectEigRef

    eCorrectTot = eCorrectTot*eVToHartree
    eCorrectEigF = eCorrectEigF*eVToHartree
    eCorrectEigRef = eCorrectEigRef*eVToHartree

    abortExecution = checkDirInitialization('exportDirInitInit', exportDirInitInit, 'input') .or. abortExecution
    abortExecution = checkDirInitialization('exportDirFinalInit', exportDirFinalInit, 'input') .or. abortExecution
    abortExecution = checkDirInitialization('exportDirFinalFinal', exportDirFinalFinal, 'input') .or. abortExecution

    call system('mkdir -p '//trim(outputDir))


    if(abortExecution) then
      write(*, '(" Program stops!")')
      stop
    endif
    
    return

  end subroutine checkInitialization

!----------------------------------------------------------------------------
  subroutine getnSpinsAndnKPoints(exportDirInitInit, nKPoints, nSpins)

    use miscUtilities, only: ignoreNextNLinesFromFile
    
    implicit none

    ! Input variables:
    character(len=300), intent(in) :: exportDirInitInit
      !! Path to export for initial charge state
      !! in the initial positions
     
    ! Output variables:
    integer, intent(out) :: nKPoints
      !! Number of k-points
    integer, intent(out) :: nSpins
      !! Number of spin channels
    
    
    if(ionode) then
    
      open(50, file=trim(exportDirInitInit)//'/input', status = 'old')
    
      read(50,*) 
      read(50,*) 
      read(50,*) 
      read(50, '(i10)') nSpins
      read(50,*) 
      read(50, '(i10)') nKPoints

    endif

    call MPI_BCAST(nSpins, 1, MPI_INTEGER, root, worldComm, ierr)
    call MPI_BCAST(nKPoints, 1, MPI_INTEGER, root, worldComm, ierr)
   
    return

  end subroutine getnSpinsAndnKPoints

!----------------------------------------------------------------------------
  subroutine getTotalEnergies(exportDirInitInit, exportDirFinalInit, exportDirFinalFinal, eTotInitInit, eTotFinalInit, eTotFinalFinal)

    use miscUtilities, only: getFirstLineWithKeyword

    implicit none

    ! Input variables:
    character(len=300), intent(in) :: exportDirInitInit
      !! Path to export for initial charge state
      !! in the initial positions
    character(len=300), intent(in) :: exportDirFinalInit
      !! Path to export for final charge state
      !! in the initial positions
    character(len=300), intent(in) :: exportDirFinalFinal
      !! Path to export for final charge state
      !! in the final positions

    ! Output variables:
    real(kind=dp), intent(out) :: eTotInitInit
      !! Total energy of the relaxed initial charge
      !! state (initial positions)
    real(kind=dp), intent(out) :: eTotFinalInit
      !! Total energy of the unrelaxed final charge
      !! state (initial positions)
    real(kind=dp), intent(out) :: eTotFinalFinal
      !! Total energy of the relaxed final charge
      !! state (final positions)

    ! Local variables:
    character(len=300) :: line
      !! Line from file


    if(ionode) then
      open(30,file=trim(exportDirFinalFinal)//'/input')
      line = getFirstLineWithKeyword(30, 'Total Energy')
      read(30,*) eTotFinalFinal
      close(30)
        !! Get the total energy of the relaxed final charge state
        !! (final positions)

      open(30,file=trim(exportDirFinalInit)//'/input')
      line = getFirstLineWithKeyword(30, 'Total Energy')
      read(30,*) eTotFinalInit
      close(30)
        !! Get the total energy of the unrelaxed final charge state
        !! (initial positions)

      open(30,file=trim(exportDirInitInit)//'/input')
      line = getFirstLineWithKeyword(30, 'Total Energy')
      read(30,*) eTotInitInit
      close(30)
        !! Get the total energy of the unrelaxed final charge state
        !! (initial positions)

    endif

    call MPI_BCAST(eTotFinalFinal, 1, MPI_DOUBLE_PRECISION, root, worldComm, ierr)
    call MPI_BCAST(eTotFinalInit, 1, MPI_DOUBLE_PRECISION, root, worldComm, ierr)
    call MPI_BCAST(eTotInitInit, 1, MPI_DOUBLE_PRECISION, root, worldComm, ierr)

    return

  end subroutine getTotalEnergies

!----------------------------------------------------------------------------
  subroutine writeEnergyTable(CBMorVBMBand, iBandIInit, iBandIFinal, iBandFInit, iBandFFinal, ikLocal, isp, refBand, eCorrectTot, eCorrectEigF, eCorrectEigRef, &
        eTotInitInit, eTotFinalInit, eTotFinalFinal, outputDir)
  
    implicit none
    
    ! Input variables:
    integer, intent(in) :: CBMorVBMBand
      !! Band of CBM (electron capture) or VBM (hole capture)
    integer, intent(in) :: iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
      !! Energy band bounds for initial and final state
    integer, intent(in) :: ikLocal
      !! Current local k-point
    integer, intent(in) :: isp
      !! Current spin channel
    integer, intent(in) :: refBand
      !! Band of WZP reference carrier

    real(kind=dp), intent(in) :: eCorrectTot
      !! Total-energy correction, if any
    real(kind=dp), intent(in) :: eCorrectEigF
      !! Correction to eigenvalue difference with final state, if any
    real(kind=dp), intent(in) :: eCorrectEigRef
      !! Correction to eigenvalue difference with reference carrier, if any
    real(kind=dp), intent(in) :: eTotInitInit
      !! Total energy of the relaxed initial charge
      !! state (initial positions)
    real(kind=dp), intent(in) :: eTotFinalInit
      !! Total energy of the unrelaxed final charge
      !! state (initial positions)
    real(kind=dp), intent(in) :: eTotFinalFinal
      !! Total energy of the relaxed final charge
      !! state (final positions)

    character(len=300), intent(in) :: outputDir
      !! Path to store energy tables

    ! Local variables:
    integer :: ibi, ibf
      !! Loop indices
    integer :: ikGlobal
      !! Current global k-point
    integer :: totalNumberOfElements
      !! Total number of overlaps to output

    real(kind=dp) :: dE
      !! Energy difference to be output
    real(kind=dp) :: dEDelta
      !! Energy to be used in delta function
    real(kind=dp) :: dEFirst
      !! Energy to be used in first-order matrix element
    real(kind=dp) :: dEPlot
      !! Energy to be used for plotting
    real(kind=dp) :: dETotElecOnly
      !! Total energy difference between charge states
      !! with no change in atomic positions to get the
      !! electronic-only energy to be used in the 
      !! zeroth-order matrix element
    real(kind=dp) :: dETotWRelax
      !! Total energy difference between relaxed
      !! charge states to be used in delta function
    real(kind=dp) :: dEZeroth
      !! Energy to be used in zeroth-order matrix element
    real(kind=dp) :: eigCBMorVBM
      !! Eigenvalue of either the CBM or VBM
    real(kind=dp) :: eigvF(iBandFinit:iBandFfinal)
      !! Final-state eigenvalues
    real(kind=dp) :: eigvI(iBandIinit:iBandIfinal)
      !! Initial-state eigenvalues
    real(kind=dp) :: refEig
      !! Eigenvalue of WZP reference carrier
    real(kind=dp) :: t1, t2
      !! Timers
    
    character(len = 300) :: text
      !! Text for header


    ikGlobal = ikLocal+ikStart-1
    
    call cpu_time(t1)
    
    write(*, '(" Writing energy table of k-point ", i2, " and spin ", i1, ".")') ikGlobal, isp
    
    open(17, file=trim(outputDir)//"/energyTable."//trim(int2str(isp))//"."//trim(int2str(ikGlobal)), status='unknown')
    
    text = "# Total number of <f|i> elements, Initial States (bandI, bandF), Final States (bandI, bandF)"
    write(17,'(a, " Format : ''(5i10)''")') trim(text)
    
    totalNumberOfElements = (iBandIfinal - iBandIinit + 1)*(iBandFfinal - iBandFinit + 1)
    write(17,'(5i10)') totalNumberOfElements, iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
    

    dETotWRelax = eTotFinalFinal - eTotInitInit + eCorrectTot
      !! Get the total energy difference between the two charge states, 
      !! including the atomic relaxation energy (with a potential energy
      !! correction defined by the user). This dE is used in the delta 
      !! function.

    write(17,'("# Total-energy difference (Hartree). Format: ''(ES24.15E3)''")') 
    write(17,'("# With relaxation (for delta function)")')
    write(17,'(ES24.15E3)') dETotWRelax


    dETotElecOnly = eTotFinalInit - eTotInitInit + eCorrectTot
      !! Get the total energy difference between the two charge states, 
      !! not including atomic relaxation (with a potential energy correction
      !! defined by the user). This dE represents the total electronic-only
      !! energy difference between the two charge states and goes in the
      !! zeroth-order matrix element.

    write(17,'("# Electronic only without relaxation (for zeroth-order matrix element)")')
    write(17,'(ES24.15E3)') dETotElecOnly
    

    text = "# Final Band, Initial Band, Delta Function, Zeroth-order, First-order, Plotting" 
    write(17, '(a, " Format : ''(2i10,4ES24.15E3)''")') trim(text)


    call readEigenvalues(CBMorVBMBand, iBandIinit, iBandIfinal, iBandFinit, iBandFfinal, ikGlobal, isp, refBand, exportDirInitInit, eigvF, eigvI, &
          eigCBMorVBM, refEig)

    do ibf = iBandFinit, iBandFfinal
      do ibi = iBandIinit, iBandIfinal

        dEDelta = dETotWRelax - abs(eigvI(ibi) - refEig + eCorrectEigRef)
          !! To get the total energy that needs to be conserved (what
          !! goes into the delta function), add the total energy 
          !! difference between the two relaxed charge states and the
          !! additional eigenvalue energy difference between the initial
          !! state and the WZP reference-carrier state. 
          !!
          !! In both hole and electron capture, the actual electron
          !! energy decreases, so the negative absolute value of the
          !! eigenvalue difference is used.
          !!
          !! The energy correction `eCorrectEigRef` is only applied to
          !! the eigenvalue energy difference between the initial state
          !! and the reference state. This correction should be zero if
          !! the reference state and initial state are both in the conduction
          !! band or both in the valence band, since eigenvalue differences
          !! within the bands are okay at the PBE level and do not need
          !! to be corrected.

        dEZeroth = dETotElecOnly - abs(eigvI(ibi) - refEig + eCorrectEigRef)
          !! The zeroth-order matrix element contains the electronic-only
          !! energy difference. We get that from a total energy difference
          !! between the two charge states in the initial positions. Like
          !! in the energy for the delta function, the additional carrier
          !! energy must also be included with a potential correction.

        dEFirst = abs(eigvI(ibi) - eigvF(ibf) + eCorrectEigF)
          !! First-order term contains only the unperturbed eigenvalue
          !! difference. The perturbative expansion has 
          !! \(\varepsilon_i - \varepsilon_f\), in terms of the actual 
          !! electron. The absolute value is needed for the hole case.
          !! A potential correction term is included in case the PBE
          !! energy levels must be used.

        dEPlot = abs(eigvI(ibi) - eigCBMorVBM)
          !! Energy plotted should be positive carrier energy in reference
          !! to the CBM (electrons) or VBM (holes)
        
        write(17, 1001) ibf, ibi, dEDelta, dEZeroth, dEFirst, dEPlot
            
      enddo
    enddo

    
    close(17)
    
    call cpu_time(t2)
    write(*, '(" Writing energy table of k-point ", i4, "and spin ", i1, " done in:                   ", f10.2, " secs.")') &
      ikGlobal, isp, t2-t1
    
 1001 format(2i7,4ES24.15E3)

    return

  end subroutine writeEnergyTable
  
!----------------------------------------------------------------------------
  subroutine readEigenvalues(CBMorVBMBand, iBandIinit, iBandIfinal, iBandFinit, iBandFfinal, ikGlobal, isp, refBand, exportDirInitInit, eigvF, eigvI, &
        eigCBMorVBM, refEig)

    use miscUtilities, only: ignoreNextNLinesFromFile
    
    implicit none
    
    ! Input variables
    integer, intent(in) :: CBMorVBMBand
      !! Band of CBM (electron capture) or VBM (hole capture)
    integer, intent(in) :: iBandIinit, iBandIfinal, iBandFinit, iBandFfinal
      !! Energy band bounds for initial and final state
    integer, intent(in) :: ikGlobal
      !! Current global k-point
    integer, intent(in) :: isp
      !! Current spin channel
    integer, intent(in) :: refBand
      !! Band of WZP reference carrier

    character(len=300), intent(in) :: exportDirInitInit
      !! Path to export for initial charge state
      !! in the initial positions

    ! Output variables:
    real(kind=dp), intent(out) :: eigCBMorVBM
      !! Eigenvalue of either the CBM or VBM
    real(kind=dp), intent(out) :: eigvF(iBandFinit:iBandFfinal)
      !! Final-state eigenvalues
    real(kind=dp), intent(out) :: eigvI(iBandIinit:iBandIfinal)
      !! Initial-state eigenvalues
    real(kind=dp), intent(out) :: refEig
      !! Eigenvalue of WZP reference carrier

    ! Local variables:
    integer :: ib
      !! Loop index

    character(len=300) :: fName
      !! File name

    
    fName = trim(exportDirInitInit)//"/eigenvalues."//trim(int2str(isp))//"."//trim(int2str(ikGlobal))

    open(72, file=fName)

    call ignoreNextNLinesFromFile(72, 2 + (iBandIinit-1))
      ! Ignore header and all bands before lowest initial-state band
    
    do ib = iBandIinit, iBandIfinal
      read(72, '(ES24.15E3)') eigvI(ib)
    enddo
    
    close(72)
    

    open(72, file=fName)

    call ignoreNextNLinesFromFile(72, 2 + (iBandFinit-1))
      ! Ignore header and all bands before lowest final-state band
    
    do ib = iBandFinit, iBandFfinal
      read(72, '(ES24.15E3)') eigvF(ib)
    enddo
    
    close(72)


    open(72, file=fName)

    call ignoreNextNLinesFromFile(72, 2 + (refBand-1))
      ! Ignore header and all bands before reference band
    
    read(72, '(ES24.15E3)') refEig
    
    close(72)


    open(72, file=fName)

    call ignoreNextNLinesFromFile(72, 2 + (CBMorVBMBand-1))
      ! Ignore header and all bands before either CBM or VBM
    
    read(72, '(ES24.15E3)') eigCBMorVBM
    
    close(72)

    
    return
    
  end subroutine readEigenvalues

end module energyTabulatorMod
