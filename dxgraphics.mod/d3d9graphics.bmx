
Strict

Import BRL.Graphics

Import Pub.DirectX

Import BRL.LinkedList
Import brl.systemdefault

Private

Global _wndClass$="BBDX9Device Window Class"

Global _driver:TD3D9graphicsDriver

Global _d3d:IDirect3D9
Global _d3dCaps:D3DCAPS9
Global _modes:TGraphicsMode[]

Global _d3dDev:IDirect3DDevice9
Global _d3dDevRefs:Int

Global _presentParams:D3DPRESENT_PARAMETERS

Global _graphics:TD3D9Graphics

Global _autoRelease:TList

Global _d3dOccQuery:IDirect3DQuery9

Type TD3D9AutoRelease
	Field unk:IUnknown
End Type

Function D3D9WndProc:Byte Ptr( hwnd:Byte Ptr,msg:Int,wp:Byte Ptr,lp:Byte Ptr ) "win32"

	bbSystemEmitOSEvent hwnd,msg,wp,lp,Null
	
	Select msg
	Case WM_CLOSE
		Return Null
	Case WM_SYSKEYDOWN
		If wp<>KEY_F4 Return Null
	End Select

	Return DefWindowProcW( hwnd,msg,wp,lp )

End Function

Function OpenD3DDevice:Int( hwnd:Byte Ptr,width:Int,height:Int,depth:Int,hertz:Int,flags:Int)
	If _d3dDevRefs
		If Not _presentParams.GetWindowed() Return False
		If depth<>0 Return False
		_d3dDevRefs:+1
		Return True
	EndIf

	Local windowed:Int=(depth=0)
	Local fullscreen:Int=(depth<>0)	

	Local pp:D3DPRESENT_PARAMETERS=New D3DPRESENT_PARAMETERS
	pp.SetBackBufferWidth(width)
	pp.SetBackBufferHeight(height)
	pp.SetBackBufferCount(1)
	pp.SetBackBufferFormat((D3DFMT_X8R8G8B8 * fullscreen) + (D3DFMT_UNKNOWN * windowed))
	pp.SetMultiSampleType(D3DMULTISAMPLE_NONE)
	pp.SetSwapEffect((D3DSWAPEFFECT_DISCARD * fullscreen) + (D3DSWAPEFFECT_COPY * windowed))
	pp.SethDeviceWindow(hwnd)
	pp.SetWindowed(windowed)
	pp.SetFlags(D3DPRESENTFLAG_LOCKABLE_BACKBUFFER)
	pp.SetFullScreen_RefreshRateInHz(hertz * fullscreen)
	pp.SetPresentationInterval(D3DPRESENT_INTERVAL_ONE)	'IMMEDIATE
	
	Local cflags:Int=D3DCREATE_FPU_PRESERVE
	
	_d3dDev = New IDirect3DDevice9
	
	'OK, try hardware vertex processing...
	Local tflags:Int=D3DCREATE_PUREDEVICE|D3DCREATE_HARDWARE_VERTEXPROCESSING|cflags
	If _d3d.CreateDevice( 0,D3DDEVTYPE_HAL,hwnd,tflags,pp,_d3dDev )<0

		'Failed! Try mixed vertex processing...
		tflags=D3DCREATE_MIXED_VERTEXPROCESSING|cflags
		If _d3d.CreateDevice( 0,D3DDEVTYPE_HAL,hwnd,tflags,pp,_d3dDev )<0
	
			'Failed! Try software vertex processing...	
			tflags=D3DCREATE_SOFTWARE_VERTEXPROCESSING|cflags
			If _d3d.CreateDevice( 0,D3DDEVTYPE_HAL,hwnd,tflags,pp,_d3dDev )<0
			
				_d3dDev = Null
				'Failed! Go home and watch family guy instead...
				Return False
			EndIf
		EndIf
	EndIf

	_presentParams=pp

	_d3dDevRefs:+1
	
	_autoRelease=New TList

	'Occlusion Query
	If Not _d3dOccQuery
		_d3dOccQuery = New IDirect3DQuery9
		If _d3ddev.CreateQuery(9,_d3dOccQuery)<0 '9 hardcoded for D3DQUERYTYPE_OCCLUSION
			DebugLog "Cannot create Occlussion Query!"
			_d3dOccQuery = Null
		EndIf
	EndIf
	If _d3dOccQuery _d3dOccQuery.Issue(2) 'D3DISSUE_BEGIN
	
	Return True
End Function

Function CloseD3DDevice()
	_d3dDevRefs:-1
	If Not _d3dDevRefs

		For Local t:TD3D9AutoRelease=EachIn _autoRelease
			t.unk.Release_
		Next
		_autoRelease=Null

		If _d3dOccQuery _d3dOccQuery.Release_
		_d3dOccQuery = Null

		_d3dDev.Release_
		_d3dDev=Null
		_presentParams=Null
	EndIf
End Function

Function ResetD3DDevice()
	If _d3dOccQuery
		_d3dOccQuery.Release_
	Else
		_d3dOccQuery = New IDirect3DQuery9
	End If
	
	If _d3dDev.Reset( _presentParams )<0
		Throw "_d3dDev.Reset failed"
	EndIf

	If _d3ddev.CreateQuery(9,_d3dOccQuery)<0
		_d3dOccQuery = Null
		DebugLog "Cannot create Occlussion Query!"
	EndIf
	If _d3dOccQuery _d3dOccQuery.Issue(2) 'D3DISSUE_BEGIN
		
End Function

Public

Global UseDX9RenderLagFix:Int = 0

Type TD3D9Graphics Extends TGraphics

	Method Attach:TD3D9Graphics( hwnd:Byte Ptr,flags:Int )
		Local rect:Int[4]
		GetClientRect hwnd,rect
		Local width:Int=rect[2]-rect[0]
		Local height:Int=rect[3]-rect[1]

		OpenD3DDevice hwnd,width,height,0,0,flags
		
		_hwnd=hwnd
		_width=width
		_height=height
		_flags=flags
		_attached=True

		Return Self
	End Method
	
	Method Create:TD3D9Graphics( width:Int,height:Int,depth:Int,hertz:Int,flags:Int)
		Local wstyle:Int

		If depth
			wstyle=WS_VISIBLE|WS_POPUP
		Else
			wstyle=WS_VISIBLE|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX
		EndIf
		
		Local rect:Int[4]

		If Not depth
			Local desktopRect:Int[4]
			GetWindowRect GetDesktopWindow(),desktopRect
				
			rect[0]=desktopRect[2]/2-width/2;		
			rect[1]=desktopRect[3]/2-height/2;		
			rect[2]=rect[0]+width;
			rect[3]=rect[1]+height;
				
			AdjustWindowRect rect,wstyle,0
		EndIf

		Local hwnd:Byte Ptr=CreateWindowExW( 0,_wndClass,AppTitle,wstyle,rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1],0,0,GetModuleHandleA(Null),Null )
		If Not hwnd Return Null

		If Not depth
			GetClientRect hwnd,rect
			width=rect[2]-rect[0]
			height=rect[3]-rect[1]
		EndIf
		
		If Not OpenD3DDevice( hwnd,width,height,depth,hertz,flags )
			DestroyWindow hwnd
			Return Null
		EndIf
		
		_hwnd=hwnd
		_width=width
		_height=height
		_depth=depth
		_hertz=hertz
		_flags=flags
		
		Return Self
	End Method
	
	Method GetDirect3DDevice:IDirect3DDevice9()
		Return _d3dDev
	End Method

	Method ValidateSize()
		If _attached
			Local rect:Int[4]
			GetClientRect _hwnd,rect
			_width=rect[2]-rect[0]
			_height=rect[3]-rect[1]
			If _width>_presentParams.GetBackBufferWidth() Or _height>_presentParams.GetBackBufferHeight()
				_presentParams.SetBackBufferWidth(Max( _width,_presentParams.GetBackBufferWidth()) )
				_presentParams.SetBackBufferHeight(Max( _height,_presentParams.GetBackbufferHeight()) )
				ResetD3DDevice
			EndIf
		EndIf
	End Method
	
	'NOTE: Returns 1 if flip was successful, otherwise device lost or reset...
	Method Flip:Int( sync:Int )
	
		Local reset:Int

		If sync sync=D3DPRESENT_INTERVAL_ONE Else sync=D3DPRESENT_INTERVAL_IMMEDIATE
		If sync<>_presentParams.GetPresentationInterval()
			_presentParams.SetPresentationInterval(sync)
			reset=True
		EndIf
		
		Select _d3dDev.TestCooperativeLevel()
		Case D3DERR_DRIVERINTERNALERROR
			Throw "D3D Internal Error"
		Case D3D_OK
			If reset

				ResetD3DDevice

			Else If _attached
			
				Local rect:Int[]=[0,0,_width,_height]
				Return _d3dDev.Present( rect,rect,_hwnd,Null )>=0

			Else

				Return _d3dDev.Present( Null,Null,_hwnd,Null )>=0

			EndIf
		Case D3DERR_DEVICENOTRESET

			ResetD3DDevice

		End Select
		
		
	End Method

	Method Driver:TGraphicsDriver()
		Return _driver
	End Method
	
	Method GetSettings:Int( width:Int Var,height:Int Var,depth:Int Var,hertz:Int Var,flags:Int Var )
		'
		ValidateSize
		'
		width=_width
		height=_height
		depth=_depth
		hertz=_hertz
		flags=_flags
	End Method

	Method Close:Int()
		If Not _hwnd Return False
		CloseD3DDevice
		If Not _attached DestroyWindow( _hwnd )
		_hwnd=0
	End Method

	Method AutoRelease( unk:IUnknown )
		Local t:TD3D9AutoRelease=New TD3D9AutoRelease
		t.unk=unk
		_autoRelease.AddLast t
	End Method
	
	Method ReleaseNow( unk:IUnknown )
		For Local t:TD3D9AutoRelease=EachIn _autoRelease
			If t.unk=unk
				unk.Release_
				_autoRelease.Remove t
				Return
			EndIf
		Next
	End Method

	
	Field _hwnd:Byte Ptr
	Field _width:Int
	Field _height:Int
	Field _depth:Int
	Field _hertz:Int
	Field _flags:Int
	Field _attached:Int

End Type

Type TD3D9GraphicsDriver Extends TGraphicsDriver

	Method Create:TD3D9GraphicsDriver()
	
		'create d3d9
		'If Not d3d9Lib Return Null
		
		_d3d=Direct3DCreate9( 32 )
		If Not _d3d Return Null

		'get caps
		_d3dCaps=New D3DCAPS9
		If _d3d.GetDeviceCaps( D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,_d3dCaps )<0
			_d3d.Release_
			_d3d=Null
			Return Null
		EndIf

		'enum graphics modes		
		Local n:Int=_d3d.GetAdapterModeCount( D3DADAPTER_DEFAULT,D3DFMT_X8R8G8B8 )
		_modes=New TGraphicsMode[n]
		Local j:Int
		Local d3dmode:D3DDISPLAYMODE = New D3DDISPLAYMODE
		For Local i:Int=0 Until n
			If _d3d.EnumAdapterModes( D3DADAPTER_DEFAULT,D3DFMT_X8R8G8B8,i,d3dmode )<0
				Continue
			EndIf
			
			Local Mode:TGraphicsMode=New TGraphicsMode
			Mode.width=d3dmode.GetWidth()
			Mode.height=d3dmode.GetHeight()
			Mode.hertz=d3dmode.GetRefreshRate()
			Mode.depth=32
			_modes[j]=Mode
			j:+1
		Next
		_modes=_modes[..j]
	
	
		Local name:Short Ptr = _wndClass.ToWString()
		'register wndclass
		Local wndclass:WNDCLASSW=New WNDCLASSW
		wndclass.SethInstance(GetModuleHandleW( Null ))
		wndclass.SetlpfnWndProc(D3D9WndProc)
		wndclass.SethCursor(LoadCursorW( Null,Short Ptr IDC_ARROW ))
		wndclass.SetlpszClassName(name)
		RegisterClassW wndclass.classPtr
		MemFree name

		Return Self
	End Method
	
	Method GraphicsModes:TGraphicsMode[]()
		Return _modes
	End Method
	
	Method AttachGraphics:TD3D9Graphics( widget:Byte Ptr,flags:Int )
		Return New TD3D9Graphics.Attach( widget:Byte Ptr,flags:Int )
	End Method
	
	Method CreateGraphics:TD3D9Graphics( width:Int,height:Int,depth:Int,hertz:Int,flags:Int)
		Return New TD3D9Graphics.Create( width,height,depth,hertz,flags )
	End Method

	Method Graphics:TD3D9Graphics()
		Return _graphics
	End Method
		
	Method SetGraphics( g:TGraphics )
		_graphics=TD3D9Graphics( g )
	End Method
	
	Method Flip( sync:Int )
		Local present:Int = _graphics.Flip(sync)
		If UseDX9RenderLagFix Then
			Local pixelsdrawn:Int
			If _d3dOccQuery
				_d3dOccQuery.Issue(1) 'D3DISSUE_END
				
				While _d3dOccQuery.GetData( Varptr pixelsdrawn,4,1 )=1 'D3DGETDATA_FLUSH
					If  _d3dOccQuery.GetData( Varptr pixelsdrawn,4,1 )<0 Exit
				Wend

				_d3dOccQuery.Issue(2) 'D3DISSUE_BEGIN
			EndIf
		End If
		
		Return present
	End Method
	
	Method GetDirect3D:IDirect3D9()
		Return _d3d
	End Method
	
End Type

Function D3D9GraphicsDriver:TD3D9GraphicsDriver()
	Global _done:Int
	If Not _done
		_driver=New TD3D9GraphicsDriver.Create()
		_done=True
	EndIf
	Return _driver
End Function
