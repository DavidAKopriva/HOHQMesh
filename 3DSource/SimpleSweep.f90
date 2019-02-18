!
!////////////////////////////////////////////////////////////////////////
!
!      SimpleExtrusion.f90
!      Created: March 28, 2013 9:55 AM 
!      By: David Kopriva  
!
!     Take a quad mesh generated by the SpecMesh2D code and
!     extrude it vertically in the "z" direction to create a
!     3D Hex mesh or rotate it about the x-axis to generate
!     a volume of revolution.
!
!////////////////////////////////////////////////////////////////////////
!
      Module SimpleSweepModule
      USE FTValueDictionaryClass
      USE SMConstants
      USE ProgramGlobals
      USE FTExceptionClass
      USE ReaderExceptions
      USE SharedExceptionManagerModule
      USE HexMeshObjectsModule
      USE ErrorTypesModule
      IMPLICIT NONE 
! 
!--------------------------------------------------------------- 
! Define methods to generate a 3D mesh from a 2D one by straight
! line extrusion or simple rotation
!---------------------------------------------------------------
! 
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_EXTRUSION_ALGORITHM_KEY    = "SIMPLE_EXTRUSION"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_ROTATION_ALGORITHM_KEY     = "SIMPLE_ROTATION"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_EXTRUSION_HEIGHT_KEY       = "height"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_SWEEP_SUBDIVISIONS_KEY     = "subdivisions"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_SWEEP_STARTNAME_KEY        = "start surface name"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_SWEEP_ENDNAME_KEY          = "end surface name"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_SWEEP_DIRECTION_KEY        = "direction"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_ROTATION_ANGLE_FRAC_KEY    = "rotation angle factor"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_SWEEP_PERIODIC_KEY         = "periodic"
      CHARACTER(LEN=STRING_CONSTANT_LENGTH), PARAMETER :: SIMPLE_ROTATION_ANGLE_KEY         = "rotation angle"
      
      INTEGER, PARAMETER :: SWEEP_FLOOR = 1, SWEEP_CEILING = 2
!

      REAL(KIND=RP), ALLOCATABLE :: chebyPoints(:)
!
!     ------------------------------------------------------------
!     Given the global node ID, get the level and 2D node location
!     in the nodes array
!     ------------------------------------------------------------
!
      INTEGER, ALLOCATABLE :: locAndLevelForNodeID(:,:)
      
!     ========      
      CONTAINS 
!     ========      
!
!////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE CheckSimpleExtrusionBlock( dict ) 
!
!        Example block is:
!
!            \begin{SimpleExtrusion}
!               direction          = 1 = x, 2 = y, 3 = z
!               height             = 10.0
!               subdivisions       = 5
!               start surface name = "bottom"
!               end surface name   = "top"
!            \end{SimpleExtrusion}
!
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         INTEGER                  :: fUnit
         CLASS(FTValueDictionary) :: dict
!
!        ---------------
!        Local variables
!        ---------------
!
         INTEGER                                :: ios
         INTEGER                                :: direction
         REAL(KIND=RP)                          :: height
         INTEGER                                :: subdivisions
         CHARACTER(LEN=LINE_LENGTH)             :: inputLine = " ", nameString
         INTEGER      , EXTERNAL                :: GetIntValue
         REAL(KIND=RP), EXTERNAL                :: GetRealValue
         CHARACTER( LEN=LINE_LENGTH ), EXTERNAL :: GetStringValue
         CLASS(FTException), POINTER            :: exception
!
!        ---------
!        Direction
!        ---------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_DIRECTION_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_DIRECTION_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------
!        Height
!        ------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_EXTRUSION_HEIGHT_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_EXTRUSION_HEIGHT_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------------
!        Subdivisions
!        ------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_SUBDIVISIONS_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_SUBDIVISIONS_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        -------------------
!        Bottom surface name
!        -------------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_STARTNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_STARTNAME_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------
!        Top surface name
!        ----------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_ENDNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleExtrusionBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_ENDNAME_KEY) // " not found in extrusion block", &
                                           typ = FT_ERROR_FATAL) 
         END IF

      END SUBROUTINE CheckSimpleExtrusionBlock
!
!////////////////////////////////////////////////////////////////////////
!
      SUBROUTINE CheckSimpleRotationBlock( dict ) 
!
!        Example block is:
!
!            \begin{SimpleRotation}
!               direction               = 1 = x, 2 = y, 3 = z
!               rotation angle factor   = 0.5
!               subdivisions            = 5
!               start surface name      = "bottom"
!               end surface name        = "top"
!            \end{SimpleExtrusion}
!
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         INTEGER                  :: fUnit
         CLASS(FTValueDictionary) :: dict
!
!        ---------------
!        Local variables
!        ---------------
!
         INTEGER                                :: ios
         INTEGER                                :: direction
         INTEGER                                :: subdivisions
         REAL(KIND=RP)                          :: angleFactor
         CHARACTER(LEN=LINE_LENGTH)             :: inputLine = " ", nameString
         INTEGER      , EXTERNAL                :: GetIntValue
         REAL(KIND=RP), EXTERNAL                :: GetRealValue
         CHARACTER( LEN=LINE_LENGTH ), EXTERNAL :: GetStringValue
         CLASS(FTException), POINTER            :: exception
!
!        ---------
!        Direction
!        ---------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_DIRECTION_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_DIRECTION_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------------
!        Angle (Fraction of PI)
!        ----------------------
!
         IF ( dict % containsKey(key = SIMPLE_ROTATION_ANGLE_FRAC_KEY) )     THEN
            angleFactor = dict % doublePrecisionValueForKey(key = SIMPLE_ROTATION_ANGLE_FRAC_KEY)
            CALL dict % addValueForKey(angleFactor,SIMPLE_ROTATION_ANGLE_KEY)
         ELSE 
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_ROTATION_ANGLE_FRAC_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ------------
!        Subdivisions
!        ------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_SUBDIVISIONS_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_SUBDIVISIONS_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        -------------------
!        Bottom surface name
!        -------------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_STARTNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_STARTNAME_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF
!
!        ----------------
!        Top surface name
!        ----------------
!
         IF ( .NOT. dict % containsKey(key = SIMPLE_SWEEP_ENDNAME_KEY) )     THEN
            CALL ThrowErrorExceptionOfType(poster = "CheckSimpleRotationBlock", &
                                           msg = "key " // TRIM(SIMPLE_SWEEP_ENDNAME_KEY) // " not found in rotation block", &
                                           typ = FT_ERROR_FATAL) 
         END IF

      END SUBROUTINE CheckSimpleRotationBlock
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE PerformSimpleMeshSweep( project, parametersDictionary, algorithmChoice )
         USE MeshProjectClass
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( MeshProject )        :: project
         CLASS( FTValueDictionary )  :: parametersDictionary
!
!        ---------------
!        Local Variables
!        ---------------
!
         CLASS(SMMesh)              , POINTER :: quadMesh
         CLASS(FTMutableObjectArray), POINTER :: quadElementsArray
         
         INTEGER                :: numberOfLayers
         INTEGER                :: numberOf2DNodes, numberOfQuadElements
         INTEGER                :: numberOfNodes
         INTEGER                :: node2DID
         INTEGER                :: N, pMutation
         INTEGER                :: algorithmChoice
         REAL(KIND=RP)          :: j, dz, h
         
         
         TYPE(SMNodePtr)   , DIMENSION(:), ALLOCATABLE :: quadMeshNodes
         CLASS(SMNode)                   , POINTER     :: currentNode
         CLASS(FTObject)                 , POINTER     :: obj
         
         INTEGER                     :: rotMap(3) = [3, 3, 1]
!                  
!
         quadMesh              => project % mesh
         N                     =  project % runParams % polynomialOrder
         numberOfQuadElements  =  project % hexMesh % numberOfQuadElements
         numberOfLayers        =  project % hexMesh % numberOfLayers
         numberOf2DNodes       =  quadMesh % nodes % count()
!
!        -----------------------------------------------------------------
!        Rotate the mesh for extrusion/rotation in the requested direction
!        -----------------------------------------------------------------
!
         pMutation = parametersDictionary % integerValueForKey(SIMPLE_SWEEP_DIRECTION_KEY)
         
         IF ( algorithmChoice == SIMPLE_EXTRUSION_ALGORITHM )     THEN
            IF ( pMutation < 3 )     THEN
               CALL quadMesh % permuteMeshDirection(pmutation)
            END IF 
         ELSE 
!
!           -------------------------------------------------------------------------
!           Rotation about the z axis requires the 2D mesh to be in a different plane
!           -------------------------------------------------------------------------
!
            IF ( rotMap(pMutation) < 3 )     THEN
               CALL quadMesh % permuteMeshDirection(rotMap(pMutation))
            END IF 
         END IF 
!
!        ---------------------------------------------------------------
!        Make sure that the nodes and elements are consecutively ordered
!        and that the edges refer to the correct elements.
!        ---------------------------------------------------------------
!
         CALL quadMesh % renumberObjects(NODES)
         CALL quadMesh % renumberObjects(ELEMENTS)
         CALL quadMesh % renumberObjects(EDGES)
!
!        ---------------------------------------
!        Gather nodes for easy access
!        TODO: The list class now has a function
!        to return an array of the objects.
!        ---------------------------------------
!
         numberOfNodes   = numberOf2DNodes*(numberOfLayers + 1)
         ALLOCATE( quadMeshNodes(numberOf2DNodes) )
         
         CALL quadMesh % nodesIterator % setToStart()
         DO WHILE( .NOT.quadMesh % nodesIterator % isAtEnd())
         
            obj => quadMesh % nodesIterator % object()
            CALL castToSMNode(obj,currentNode)
            node2DID = currentNode % id
            quadMeshNodes(node2DID) % node => currentNode
         
            CALL quadMesh % nodesIterator % moveToNext() 
         END DO 
!
!        ---------------------------------------------------------------
!        Allocate connections between global ID and local (2D, level) id
!        ---------------------------------------------------------------
!
         ALLOCATE( locAndLevelForNodeID(2, numberOfNodes) )
!
!        ------------------------------------------------
!        Ratation is done by sweeping then applying the 
!        rotation to the result.
!        ------------------------------------------------
!
         IF ( algorithmChoice == SIMPLE_EXTRUSION_ALGORITHM )     THEN
            h   = parametersDictionary % doublePrecisionValueForKey( SIMPLE_EXTRUSION_HEIGHT_KEY )
            dz = h/project % hexMesh % numberofLayers
         ELSE
            h   = PI * parametersDictionary % doublePrecisionValueForKey( SIMPLE_ROTATION_ANGLE_KEY )
            dz = h/project % hexMesh % numberofLayers
         END IF 
!
!        ------------------------------
!        Sweep the skeleton of the mesh
!        ------------------------------
!
         CALL sweepNodes( quadMeshNodes, project % hexMesh, dz, pMutation )
         CALL sweepElements( quadMesh, project % hexMesh, numberofLayers, algorithmChoice, parametersDictionary )
!
!        -------------------------------------
!        Sweep the internal degrees of freedom
!        -------------------------------------
!
         quadElementsArray => quadMesh % elements % allObjects()
         CALL SweepInternalDOFs(hex8Mesh          = project % hexMesh, &
                                quadElementsArray = quadElementsArray, &
                                N                 = N,                 &
                                dz                = dz,                &
                                pmutation         = pMutation)
!
!        ------------------------------
!        Rotate the mesh when requested
!        ------------------------------
!
         IF ( algorithmChoice == SIMPLE_ROTATION_ALGORITHM )     THEN
            !^ TODO:
         END IF 
          
         CALL release(quadElementsArray)
         DEALLOCATE(quadMeshNodes)
!

      END SUBROUTINE PerformSimpleMeshSweep
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE sweepNodes( quadMeshNodes, hex8Mesh, dz, pMutation )
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( StructuredHexMesh )    :: hex8Mesh
         REAL(KIND=RP)                 :: dz
         TYPE(SMNodePtr), DIMENSION(:) :: quadMeshNodes
         INTEGER                       :: pMutation
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER                           :: numberOf2DNodes
         INTEGER                           :: nodeID
         INTEGER                           :: j, k
         INTEGER                           :: numberOfLayers
!
!        ---------------------------------------
!        Generate the new nodes for the hex mesh
!        layer by layer. Order the new node IDs
!        layer by layer, too.
!        ---------------------------------------
!
         numberOf2DNodes = SIZE(quadMeshNodes)
         numberOfLayers  = hex8Mesh % numberofLayers
                      
         nodeID = 1
         DO j = 0, numberofLayers
            DO k = 1, numberOf2DNodes
               hex8Mesh % nodes(k,j) % globalID = nodeID
               hex8Mesh % nodes(k,j) % x  = extrudedNodeLocation(baseLocation = quadMeshNodes(k) % node % x, &
                                                                 delta        = j*dz, &
                                                                 pmutation    = pMutation)
               locAndLevelForNodeID(1,nodeID) = k
               locAndLevelForNodeID(2,nodeID) = j
               nodeID = nodeID + 1
            END DO   
         END DO
!
      END SUBROUTINE sweepNodes
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE SweepInternalDOFs( hex8Mesh, quadElementsArray, N, dz, pmutation)
         USE SMMeshClass
         USE FTMutableObjectArrayClass
         IMPLICIT NONE  
!
!        ---------
!        Arguments
!        ---------
!
         CLASS(FTMutableObjectArray), POINTER  :: quadElementsArray
         TYPE ( StructuredHexMesh )            :: hex8Mesh
         REAL(KIND=RP)                         :: dz
         INTEGER                               :: pMutation
         INTEGER                               :: N
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER                   :: l, m, i, j, k
         REAL(KIND=RP)             :: x(3), zz, y(3)
         CLASS(FTObject) , POINTER :: obj
         CLASS(SMElement), POINTER :: e
!
!        ------------------------------------------
!        Extend the face points on the quad element
!        up through the hex element.
!        ------------------------------------------
!
         DO l = 1, hex8Mesh % numberOfQuadElements
            obj => quadElementsArray % objectAtIndex(l)
            CALL castToSMelement(obj,e)
            DO m = 1, hex8Mesh % numberofLayers
               DO k = 0, N
                  zz = (m-1)*dz + 0.5_RP*dz*(1.0 - COS(k*PI/N))
                  DO j = 0, N 
                     DO i = 0, N
                        x = permutePosition(x = e % xPatch(:,i,j),pmutation = pMutation)
                        y = extrudedNodeLocation(baseLocation = x, delta = zz, pmutation = pMutation)
                        hex8Mesh % elements(l,m) % x(:,i,j,k) = y
                     END DO 
                  END DO 
               END DO 
            END DO   
         END DO
         
      END SUBROUTINE SweepInternalDOFs
!
!//////////////////////////////////////////////////////////////////////// 
! 
      SUBROUTINE sweepElements( quadMesh, hex8Mesh, numberofLayers, algorithmChoice, parametersDictionary )
!
!        -------------------------------
!        Call after generating the nodes
!        -------------------------------
!
         USE MeshProjectClass  
         IMPLICIT NONE
!
!        ---------
!        Arguments
!        ---------
!
         TYPE ( SMMesh )             :: quadMesh
         TYPE ( StructuredHexMesh )  :: hex8Mesh
         INTEGER                     :: numberOfLayers
         TYPE( FTValueDictionary)    :: parametersDictionary
         INTEGER                     :: algorithmChoice
!
!        ---------------
!        Local Variables
!        ---------------
!
         INTEGER                           :: numberOfQuadElements
         INTEGER                           :: elementID, nodeID, node2DID, quadElementID
         INTEGER                           :: j, k
         INTEGER                           :: pMutation
         INTEGER   :: flagMap(4) = [1,4,2,6]
         
         
         CLASS(SMNode)                   , POINTER     :: node
         CLASS(SMElement)                , POINTER     :: currentQuadElement
         CLASS(FTObject)                 , POINTER     :: obj
         
         numberOfQuadElements = hex8Mesh % numberOfQuadElements
         pMutation            = parametersDictionary % integerValueForKey(SIMPLE_SWEEP_DIRECTION_KEY)
!
!        ---------------------------------
!        Build the elements layer by layer
!        ---------------------------------
!
         elementID = 1
         DO j = 1, numberOfLayers
            quadElementID = 1
            
            CALL quadMesh % elementsIterator % setToStart()
            
            DO WHILE( .NOT. quadMesh % elementsIterator % isAtEnd() )
               obj => quadMesh % elementsIterator % object()
               CALL castToSMElement(obj,currentQuadElement)
!
!              -----------------------
!              Set the element nodeIDs
!              -----------------------
!
               DO k = 1, 4
!
!                 -------------
!                 Bottom of hex
!                 -------------
!
                  obj => currentQuadElement % nodes % objectAtIndex(k)
                  CALL cast(obj,node)
                  node2DID = node % id
                  nodeID   = hex8Mesh % nodes(node2DID,j-1) % globalID
                  hex8Mesh % elements(quadElementID,j) % nodeIDs(k) = nodeID
!
!                 ----------
!                 Top of hex
!                 ----------
!
                  nodeID = hex8Mesh % nodes(node2DID,j) % globalID
                  hex8Mesh % elements(quadElementID,j)  % nodeIDs(k+4) = nodeID
                  
               END DO
!
!              ------------------------------------------------------------------
!              Set boundary condition names at the start and end of the extrusion
!              as defined in the control file
!              ------------------------------------------------------------------
!
               IF ( j == 1 )     THEN
                  hex8Mesh % elements(quadElementID,j) % bFaceName(3) = &
                  parametersDictionary % stringValueForKey(key             = SIMPLE_SWEEP_STARTNAME_KEY,&
                                                           requestedLength = LINE_LENGTH)
               END IF 
               IF (j == numberOfLayers)     THEN 
                  hex8Mesh % elements(quadElementID,j) % bFaceName(5) = &
                  parametersDictionary % stringValueForKey(key             = SIMPLE_SWEEP_ENDNAME_KEY,&
                                                           requestedLength = LINE_LENGTH)
               END IF 
!
!              ----------------------------------------------------------------
!              Use edge info of parent quad element to set boundary curve flags
!              and names for the new hex element
!              ----------------------------------------------------------------
!
               DO k = 1, 4 
                  IF ( currentQuadElement % boundaryInfo % bCurveFlag(k) == ON )     THEN
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(flagMap(k)) = ON 
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(3) = ON 
                     hex8Mesh % elements(quadElementID,j) % bFaceFlag(5) = ON 
                  END IF 
                  hex8Mesh % elements(quadElementID,j) % bFaceName(flagMap(k)) &
                                      = currentQuadElement % boundaryInfo % bCurveName(k)
               END DO 
               
               quadElementID  = quadElementID + 1
               elementID      = elementID + 1
               
               CALL quadMesh % elementsIterator % moveToNext()
            END DO 
            
         END DO 
!
      END SUBROUTINE sweepElements
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION extrudedNodeLocation(baseLocation,delta,pmutation)  RESULT(x)
         IMPLICIT NONE  
         REAL(KIND=RP) :: baseLocation(3), delta
         INTEGER       :: pmutation
         REAL(KIND=RP) :: x(3)
               
         x              = baseLocation
         x(pmutation)   = delta 
      END FUNCTION extrudedNodeLocation
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION rotatedNodeLocation(baseLocation,theta,pmutation)  RESULT(x)
         IMPLICIT NONE  
         REAL(KIND=RP) :: baseLocation(3), theta
         INTEGER       :: pmutation
         REAL(KIND=RP) :: x(3)
         REAL(KIND=RP) :: r
               
         x              = baseLocation
         SELECT CASE ( pmutation )
            CASE( 1 ) ! rotation about x-Axis
               r    = baseLocation(2)
               x(2) = r*COS(theta)
               x(3) = r*SIN(theta)
            CASE (2)  ! rotation about y-Axix
               r    = baseLocation(1)
               x(1) = r*COS(theta)
               x(3) = r*SIN(theta)
            CASE (3)  ! rotation about z-Axis
               r    = baseLocation(2)
               x(2) = r*COS(theta)
               x(1) = r*SIN(theta)
            CASE DEFAULT 
         END SELECT 
         
      END FUNCTION rotatedNodeLocation
!
!//////////////////////////////////////////////////////////////////////// 
! 
      FUNCTION permutePosition(x, pmutation)  RESULT(y)
         IMPLICIT NONE  
         REAL(KIND=RP), DIMENSION(3) :: x, y
         INTEGER                     :: pmutation
         
         y  = CSHIFT(x, SHIFT = -pmutation)

      END FUNCTION permutePosition

      END Module SimpleSweepModule 