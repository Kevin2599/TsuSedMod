function [modelOUT]=Tsunami_InvVelModel_V4p0(varargin)
%Tsunami_InvVelModel_V4p0 - Estimates water velocity from tsunami sediment deposit.
%
% Assumes steady uniform flow.
% Bruce Jaffe, USGS
% First version written March 12, 2001
%
% Functions needed: phi2mm.m, sw_dens0.m, sw_smow.m, KinVisc.m, UstarCrit.m, zoWS.m,  
%                   dietrichWs.m, Setvel1.m, tubesetvel.m, linearK.m, parabolicK.m, gelfK.m    
% 	Inputs:
%		th- deposit thickness (m)
%		h- estimate of water depth (m)
%		sal- salinity (psu)
%		wtemp- water temperature (deg. C)
%		nclass- number of sed sizes to consider
%		Cb- total bed concentration (1-porosity), usually 0.65
%		fr- fractional portion of each grain size in bed
%       phi- grain size in phi units for each size class
%		RhoS- sediment density (kg/m^3) for each size class        
%		Dmn- mean grain diamter(mm);
%       ustrc- shear velocity, initial guess input and then allowed to change
%       ustrcAdjFac- Factor that sets how quickly ustrc is adjusted during iterations
%       nit- number of iterations to run
%       diststep- how often to iterate size classes versus concentration
%       nz- number of vertical bins for calculations
%		vk-  Van Karmen's constant
%		g0- the resuspension coefficient  *** standard value 1.4 x 10^-4
%           from Hill et al., 1989
%		concconvfactor- % difference between modeled and observed concentration 
%           difference allowed
%       sizeconvfactor- set the % difference between modeled and observed size 
%           distribution allowed
%       var- sets eddy viscosity shape; 1=linear, 2=parbolic,
%       3=[Gelfenbaum]
%		
%	Used: 
%		ssfrwanted- suspended size distribution wanted
%       ssconverge- keeps track of whether amount of sediment in each size class 
%           is acceptable
%       ssoffa- array to track of how far off the suspended sediment concentration 
%           is from desired concentration 
%       ssfra- array to track of suspended sediment concentration in each size class
%       fra- array to track of bed sediment concentration in each size class
%       offa- array to track how far total suspended load is off from load
%           required to create deposit
%       ustrca- array to track how  u*c changes with iteration
%
%	Calculated by functions:
%       d- grain diameter (initially in mm, so I don't miscount zeros, later set to m)
%		rhow- density of water (kg/m^3)sedstat
%		kinvisc- kinematic viscosity of water (m^2/s), usually about 10^-6
%       UcritDmn-  critical shear velocity for mean grain size
%       zotot- Z naut total, from Nickaradse bed roughness and saltation bed roughness
%		ws- settling velocity (m/s)
%		ucrit- critical shear velocity for initiation of sediment transport
%       z- log space elevation values where concentrations and velocities are calculated
%		K- eddie viscosity (m/s^2)
%		zo- Z naut, zero velocity intercept
%
%	Calculated:
%       zoN- Nickaradse grain roughness
%      	ustrc  = current shear velocity, u*c [m/s], initial value 0.1 m/s
%		s- ratio of density of sediment to density of fluid density for each size class
%   	thload- sediment load needed to get observed tsunami deposit thickness
%		tcrit- critical shear stress (N/m^2)
%		taub-  bottom shear stress due to currents (N/m^2)
%		taustar- bottom shear stress normalized by critical shear stress
%		S- excess shear stress
%       Ca- reference concentration (volume conc; m3/m3) *** ref. elevation is zo, not 2 grain diameters 
%		Ki- integral of 1/eddie viscosity
%       C- Suspended-sediment profile (calculated for each size class)
%       G- Suspended load (calculated for each size class)
%       off- normalized difference between suspended load and load required to create deposit
%		spd- mean current speed calculated using current shear velocity (m/s)
%       froude- Froude number calculated using maximum speed
%
%    OPTIONS:
%       'infile' - specifies filename of model input file. 
%
%       'outfile'- writes results to comma-separated (.csv) file. If the
%       specified output file already exists, results will be appended to
%       current file.  
%
%       'grading'- plots results of grading function . The default output 
%       depth of this function is 0.01 m.  To modify the defaut, the user 
%       can specify an additional arguement of a vector of depths or a single value.
%       ***Bruce, you may want to elaborate on this****  

%MB OPTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Option: 'matIn'
%read in input grain size from structure (matIn)
%Option: 'h'
%Set flow depth
%Option: 'zotot'
%Set roughness, Z_0
%Option: 'mannings'
%Set roughness, manning's n
%requires function "macwilliams" 
%Option: 'th'
%Set deposit thickness
%Option: 'rhow'
%Set fluid density
%Option: 'eddyViscShape'
%Set eddy viscocity Shape
% 1=linearK, 2=parabolicK, 3=gelfK, 4=newK
%Experimental
%Option: 'Kmult'
%multiply K by set value to alter eddy viscocity profile 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    USAGE
%       [modelOut] = Tsunami_InvVelModel_V3p7MB;
%
%    these options still apply, however only one structure is returned
%    OLD USGAGE EXAMPLES:
%       [modelP,siteInfo,datain,details,results]=Tsunami_InvVelModel_V3p5;
%       
%       [modelP,siteInfo,datain,details,results]=Tsunami_InvVelModel_V3p5('infile','C:\exampleFile.xls');
%
%       [modelP,siteInfo,datain,details,results]=Tsunami_InvVelModel_V3p5('grading',0.01);
%          where 0.01 specifies set interval (m) for grain statistics for the synthetic deposit
%
%       [modelP,siteInfo,datain,details,results]=Tsunami_InvVelModel_V3p5('grading',[0.01,0.03,0.04,0.8]); 
%          where [ ] specifies variable intervals (m) for grain statistics
%          for the synthetic deposit
%
%       [modelP,siteInfo,datain,details,results]=Tsunami_InvVelModel_V3p5('outfile',...
%       'modelResults.csv');
%
%  	written March 12, 2001 by Bruce Jaffe, based on code written by Chris
%  	Sherwood, documented 7/03
%   Significant code clean-ups and user friendly input added by Andrew Stevens from March to October, 2007
%   modfied on 11/29/07 by Bruce Jaffe, modification of Andrew Stevens' cleaned-up code including
%   allowing single size class runs
%   modified 4/29/08 to output weight percent (Bruce Jaffe) and to fix grading function
%   interval error (Mark Buckley)
%   V3p8 by Brent Lunghino (see commit log on GitHub)
%   V4p0 updated on 4/29/15 by Brent Lunghino


fprintf(1,'\n%s\n',[datestr(now),' --- ',mfilename,' running...'])

%read in model inputs from excel file
if any(strcmpi(varargin,'infile'))==1;
    indi=strcmpi(varargin,'infile');
    ind=find(indi==1);
    fname=varargin{ind+1};

    isFile=exist(fname,'file');
    if isFile==0
        errordlg([fname, ' not found in Matlab path, '...
            'make sure the name is correct and try again.']);
        modelP=[]; siteInfo=[]; datain=[];
    else
        [modelP,siteInfo,datain]=readModelFile(fname);
    end
else
    [fname, pname] = uigetfile('*.xls', 'Pick a .xls file with Model Parameters');
    [modelP,siteInfo,datain]=readModelFile([pname,fname]);
end

tic
%%%%%%MB EDIT%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Below are various varargin options. If not prompted defaults in .xls file will be used.

%Option: 'matIn'
%read in input grain size from structure (matIn)
if any(strcmpi(varargin,'matIn'))==1;
    indi=strcmpi(varargin,'matIn');
    ind=find(indi==1);
    matIn=varargin{ind+1};
    clear datain.phi datain.weights datain.interval_weights siteInfo.depositThickness
    datain.phi=matIn.phi;
    datain.weights=matIn.wt;
    datain.interval_weights = matIn.interval_weights;
    siteInfo.depositThickness=matIn.th;
    siteInfo.matIn = matIn;
end

%Option: 'sname'
%Set site name
if any(strcmpi(varargin,'sname'))==1;
    indi=strcmpi(varargin,'sname');
    ind=find(indi==1);
    clear siteInfo.name
    siteInfo.name=varargin{ind+1};
end

%Option: 'h'
%Set flow depth
if any(strcmpi(varargin,'h'))==1;
    indi=strcmpi(varargin,'h');
    ind=find(indi==1);
    clear siteInfo.depth
    siteInfo.depth=varargin{ind+1};
end

%Option: 'zotot'
%Set roughness, Z_0
if any(strcmpi(varargin,'zotot'))==1;
    indi=strcmpi(varargin,'zotot');
    ind=find(indi==1);
    clear modelP.bedRoughness
    modelP.bedRoughness=varargin{ind+1};
end

%Option: 'mannings'
%Set roughness, manning's n
%requires function "macwilliams" 
if any(strcmpi(varargin,'mannings'))==1;
    indi=strcmpi(varargin,'mannings');
    ind=find(indi==1);
    clear modelP.bedRoughness
    modelP.bedRoughness=macwilliams(siteInfo.depth,0.41,varargin{ind+1},0);
end

%Option: 'th'
%Set deposit thickness
if any(strcmpi(varargin,'th'))==1;
    indi=strcmpi(varargin,'th');
    ind=find(indi==1);
    clear siteInfo.depositThickness
    siteInfo.depositThickness=varargin{ind+1};
end

%Option: 'rhow'
%Set fluid density
if any(strcmpi(varargin,'rhow'))==1;
    indi=strcmpi(varargin,'rhow');
    ind=find(indi==1);
    rhow=varargin{ind+1};
end

%Option: 'eddyViscShape'
%Set eddy viscocity Shape
% 1=linearK, 2=parabolicK, 3=gelfK, 4=newK
if any(strcmpi(varargin,'eddyViscShape'))==1;
    indi=strcmpi(varargin,'eddyViscShape');
    ind=find(indi==1);
    clear modelP.eddyViscShape
    modelP.eddyViscShape=varargin{ind+1};
end

%Experimental
%Option: 'Kmult'
%multiply K by set value to alter eddy viscocity profile 
if any(strcmpi(varargin,'Kmult'))==1;
    indi=strcmpi(varargin,'Kmult');
    ind=find(indi==1);
    Kmult=varargin{ind+1};
else
    Kmult=1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%re-name input variables to match input list
%model parameters
nit             = modelP.numIterations;
vk              = modelP.vonK;
nz              = modelP.numBins;
g0              = modelP.resuspCoeff;
concconvfactor  = modelP.concConvFac;
sizeconvfactor  = modelP.sizeConvFac;
ustrc           = modelP.shearVel;
zotot           = modelP.bedRoughness;
setType         = modelP.setType;
var             = modelP.eddyViscShape;

%site info
t               = siteInfo.description;
th              = siteInfo.depositThickness;
h               = siteInfo.depth;
sal             = siteInfo.salinity;
wtemp           = siteInfo.waterTemp;
RhoS            = siteInfo.sedDensity;    
Cb              = siteInfo.bedConc;

%data 
phi             = datain.phi;
fr              = datain.weights;

% end data input


nclass = length(fr);            % number of sed sizes to consider
fr=fr(:);                       % make fr into a column vector



fr=fr./sum(fr);                 % normalize size fractions to avoid rounding errors in sed. analysis causing problems
ssfrwanted=fr;					% susp sed size distribution wanted, keep this for comparison with model results

ssconverge=ones(nclass,1); 		% initiate ss converge to 1 for all size classes (does  converge)
ssconverge=(fr==0).*ssconverge; % reset ss converge values to 0 (does not converge) for all size classes with sediments
sizeconverge=sizeconvfactor*ones(nclass,1);	% set percent difference in size distribution allowed, same value for all sizes

D=phi2mm(phi);                  % convert grain size to mm for settling velocity calculation using Dietrich's formulae
d=0.001*D;                      % convert classes to m for calculating settling velocity using other forumlae and for UstarC calculation
if (nclass==1);                 % allows program to run with only 1 size class without crashing in sedstats function
    dMean_phi=phi(1);
else
    [dMean_phi,stdeva,m3a,m4a,fwmedian1,fwmean1,fwsort1,fwskew1,fwkurt1]=sedstats(phi,fr');  %calculate mean grain size
end
dMean_mm=phi2mm(dMean_phi);     % convertmean grain size in phi to mm
Dmn=0.001*dMean_mm;             % convert mean grain size to m for calculating bed roughess
rhos = RhoS*ones(nclass,1);     % set sediment density, same value for all sizes


%%%%%%%% calculate water parameters

%%%%MB EDIT%%%%%%%%%%%%%
% calculate the density of seawater if not set in vargarin options
if exist('rhow')~=1;
    rhow = sw_dens0(sal,wtemp);				% calculate the density of seawater [kg/m^3]
end
%%%%%%%%%%%%%%%%%%%%%%%%
[kinvisc]=KinVisc(wtemp);				% calculate the kinematic viscosity of the water

%calculate s
s=rhos/rhow;


% calculate critical shear stress (N/m2) and settling velocity for each
% size class
switch setType
    case 1
        for  i=1:nclass
            [ws(i)]=-tubesetvel(phi(i))/100;
            Ucrit(i)=UstarCrit(d(i),kinvisc,s(i));
            tcrit(i)=rhow*Ucrit(i)^2;
        end
    case 2
        for  i=1:nclass
            [ws(i)]=-dietrichWs(wtemp,D(i),rhos(i)/1000,rhow/1000,0.005)/100;
            Ucrit(i)=UstarCrit(d(i),kinvisc,s(i));
            tcrit(i)=rhow*Ucrit(i)^2;
        end
    case 3
        for  i=1:nclass
            [ws(i)]= Setvel1(d(i),kinvisc,s(i));
            Ucrit(i)=UstarCrit(d(i),kinvisc,s(i));
            tcrit(i)=rhow*Ucrit(i)^2;
        end
end

thload=th*Cb;  % suspended sediment load to make deposit of observed thickness, thickness times Cb = 1-porosity 

%%%%%%%% calculate zo

zoN=Dmn/30;		% Nickaradse bed roughness

% guess ustrc to make deposit, need this to calculate zos, bed roughness from moving flat bed, saltation

%%%%  Make the initial ustrc an input, also make ustrcAdjFac an input and
%%%%  delelet lines 228 and 229
ustrcAdjFac=0.01;
UcritDmn=UstarCrit(Dmn,kinvisc,2650/rhow);	% need critical shear velocity for mean grain size to calculate bed roughness
if isnumeric(modelP.bedRoughness)~=1;
    zotot=zoN+zoWS(Dmn,ustrc,UcritDmn,rhow);  	% zo total (Nickaradse bed roughness and Wiberg/Smith bed roughness from saltation, 
end                                             % ref. Wiberg and Rubin, 1989 JGR

% ***  Begin loop to determine shear velocity needed to suspend deposit
% This loops used to assume that the bed sediment disribution is the same as the suspended sediment distribution 
% This gives reasonable results when the size of the bed material is 

					    % number of iterations to run
diststep=1;					        % adjusts sediment grain size distribution every 2nd iteration
ssoffa=zeros(nit/diststep,nclass);  % initiate array tracking ss deviation from desired concentration for iteration=1:nit
ssfra=ones(nit/diststep,nclass);	% initiate array tracking ss concentrations for iteration=1:nit
fra=zeros(nit/diststep,nclass);     % initiate array tracking bed sediment concentrations for iteration=1:nit
offa=zeros(nit,1); 			        % inititate array to track how far total suspended load is off from desired suspended load 
ustrca=zeros(nit,1); 		        % inititate array to track how  u*c changes with iteration

for iteration=1:nit

    fr=fr./sum(fr); 		        % make sure fractions add up to 1
    if(all(ssconverge) && cconverge); break; end		% if both conc and size are good enough, get outta here
    taub = rhow*ustrc^2;            % bottom stress
    taustar = taub./tcrit;
    S  = taustar-1;                 % normalized excess shear stress
    S = S.*(S>0);                   % returns zero when taub<=tcrit  *** this was changed on 2/7/00
    S=S';
    Ca = g0*Cb*fr.* S./(1+g0*S);    % reference concentration (volume conc; m3/m3) *** ref. elevation is zo, not 2 grain diameters
    % resuspension coefficient(g0) for flat moveable bed
    % Madsen 94a "Susp. Sed. Trans
    % on the inner shelf waters during extreme storms"
    % ICCE pg 1849 Madsen, Chisholm, Wright based on
    % Wikramanayake 92 PhD thesis
    % firs
    % t shot, might want to change this using mean current litterature**
    % ...log-spaced z grid
    z = logspace(log10(zotot),log10(h),nz)';

    % ..elevation of suspended load, SL
    zsl=z(1:nz-1)+diff(z);

    % elevation of speed calculated from eddy viscosity
    zmid=(z(1:nz-1)+z(2:nz))/2;

    % calculate eddy viscosity profile

    % 'var=1 is linear eddy viscosity profile, var=2 is parabolic profile, var=3 is gelf profile'
    % var=4 is newK added by Mark Buckley
    % Kmult is a multiplication factor for K, if it is not specified it
    % defaults to 1.
    %%%%%% MB EDIT %%%%%%%%%%%%%%%%%%%%
    K=(var==1)*linearK(z,h,ustrc)+(var==2)*parabolicK(z,h,ustrc)...
        +(var==3)*gelfK(z,h,ustrc)+(var==4)*newK(z,h,ustrc);
    K=K*Kmult;
    Kmid=(var==1)*linearK(zmid,h,ustrc)+(var==2)*parabolicK(zmid,h,ustrc)...
        +(var==3)*gelfK(zmid,h,ustrc)+(var==4)*newK(zmid,h,ustrc);
    Kmid=Kmid*Kmult;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Calculate current and eddie viscosity profiles
    % Integral of 1/K
    Ki = cumsum( 2 ./(K(1:nz-1,1)+K(2:nz,1)) .*diff(z) );

    % calculate the suspended-sediment profile and sediment load for each class

    for i=1:nclass,
        % Suspended-sediment profile
        C(:,i) = [Ca(i);Ca(i).*exp(ws(i)*Ki)];

        SL(:,i) = 0.5*(C(1:nz-1,i)+C(2:nz,i)).*diff(z); % used to create deposit by sediment settling

        % Depth-intergral of sediment profile
        G(i) = sum(SL(:,i));
    end

    %********* set cconverge to 0  ***
    cconverge=0;

    off=sum(G)/thload-1;                            % normalized difference between suspended load and load required to create deposit
    offa(iteration)=off;
    if (abs(off)*100 < concconvfactor)
        cconverge=1;
    end
    if(all(ssconverge) && cconverge); break; end		% if both conc and size are good enough, get outta here
    ustrca(iteration)=ustrc;
    ustrc=ustrc*(1-ustrcAdjFac*off);                % change ustrc based on how far off suspended load is from desired value
    
    
    if isnumeric(modelP.bedRoughness)~=1;
        zotot=zoN+zoWS(Dmn,ustrc,UcritDmn,rhow);  	 % recalculate bed roughness
    end

    % check for convergence for size of suspended sediment and adjust bed sediment distribution every diststep
    doss=diststep*fix(iteration/diststep);

    if(doss == iteration)                           % redo distribution every diststep steps

        ssfr=G./sum(G);							        % calculate susp sed size distribution for model
        ssfra(doss/diststep,:)=ssfr;
        fra(doss/diststep,:)=fr';
        ssfr=(ssfr(:));								    % make ssfr a column vector
        % keep track of whether model is converging ** array indexes
        % different from iteration
        for k=1:nclass
            if  (ssfrwanted(k) ~= 0)				    % only adjust for classes with material in them
                ssoff=ssfr(k)/ssfrwanted(k)-1;
                ssoffa(doss/diststep,k)=ssoff;
                fr(k)=fr(k)*(1-0.01*ssoff);	                % change bed grain size distribution based on suspended load distribution

                if (abs(ssoff)*100 <sizeconverge(k)) 		% check for convergence for each size class
                    ssconverge(k)=1;						% set to 1 if OK
                end
            end
            if(all(ssconverge) && cconverge); break; end		% if both conc and size are good enough, get outta here
        end
    end

end

spd=[0;cumsum(diff(z).*ustrc*ustrc./Kmid)];   % speed calculated using eddy viscosity profile integration

if iteration==nit
    errordlg('Model may not have converged, use extreme caution with these results')
end

predictedssload=sum(G);
maximumspeed=max(spd);
avgspeed=sum( 0.5*(spd(1:nz-1)+spd(2:nz)) .* diff(z) )/h;
MaxFroude=maximumspeed/sqrt(9.8*h);
AvgFroude=avgspeed/sqrt(9.8*h);
if (var==1); ed='Linear';end
if (var==2); ed='Parabolic';end
if (var==3); ed='Gelfenbaum';end
%stop clock
et=toc;
end_time = datestr(now);

% BL edit output file now written by script called from run file

%write details to structure
details.ssfrwanted=ssfrwanted;
details.ssconverge=ssconverge;
details.cconverge=cconverge;
details.ssfra=ssfra;
details.fra=fra;
details.ssoffa=ssoffa;
details.offa=offa;
details.C=C;
details.G=G;
details.ws=ws;
details.SL=SL;
details.z=z;
details.zsl=zsl;
details.zmid=zmid;
details.ustrca=ustrca;
details.S=S;
details.spd=spd;
details.elapsed_time = et;
details.timestamp = end_time;
details.iterations = iteration;
details.n_sedsize_class = nclass;
details.mean_grain_diameter_m = Dmn;
details.eddy_viscosity_profile = ed;
details.Kmult = Kmult;

%write results into structure
results.zoN=zoN;
results.zotot=zotot;
results.ustrc=ustrc;
results.s=s;
results.thload=thload;
results.predicted_ss_load = predictedssload;
results.tcrit=tcrit;
results.taub=taub;
results.taustar=taustar;
results.S=S;
results.SL=SL;
results.phi=phi;
results.zsl=zsl;
results.Ca=Ca;
results.total_Ca = sum(Ca); % concentration for all size classes
results.Ki=Ki;
results.C=C;
results.G=G;
results.depth_averaged_total_suspended_load = sum(G) / h;
results.off=off;
results.spd=spd;
results.AvgSpeed=avgspeed;
results.MaxSpeed=maximumspeed;
results.MaxFroude=MaxFroude;
results.AvgFroude=AvgFroude;
% these are filled below if grading is calculated
results.RSE = NaN;
results.mean_RSE = NaN;

%do we want calcluate grading?

if any(strcmpi(varargin,'grading'))==1;
    ind=find(strcmpi(varargin,'grading')==1);
    
    if isnumeric(varargin{ind+1});
        intv=varargin{ind+1};
    else
        intv=0.01;
    end
    
    porosity=1-Cb;
    [gradOut]=grading(SL,phi,zsl,intv,porosity);
    
    assignin('base','gradingD',gradOut);
    
    % calculate root square error
    results.RSE = root_square_error((datain.interval_weights*100)', flipud(gradOut.wpc));
    results.mean_RSE = mean(results.RSE);
    
end

% print run details to console
fprintf(1,'%s\n',['Done. Elapsed run time: ',...
    sprintf('%.2f',et),' s'])
fprintf(1,'\n%s\n', matIn.Trench_ID)
fprintf(1, '%s %4.1f - %4.1f %s\n\n', 'Depth range', matIn.Drange, 'cm')
fprintf(1,'%s %4.3f %s\n','Deposit thickness:',th,'m')
fprintf(1,'%s %4.1f %s\n','Water depth:',h,'m')
fprintf(1,'%s %i\n','Size classes',nclass)
fprintf(1,'%s %.3e %s\n','D mean:',Dmn,'m')
fprintf(1,'%s\n',['Viscosity Profile: ',ed])
fprintf(1,'\n%s\n','Model Results');
fprintf(1,'%s %4.2f %s\n','Shear velocity:',ustrc,'m/s')
fprintf(1,'%s %.3e\n','Bed Roughness:',zotot)
fprintf(1,'%s %4.3f %s\n','Sediment load needed:',thload,'m')
fprintf(1,'%s %4.3f %s\n','Sediment load predicted:',predictedssload,'m')
fprintf(1,'%s %5.2f %s\n','Max. speed:',maximumspeed,'m/s')
fprintf(1,'%s %5.2f %s\n','Avg. speed:',avgspeed,'m/s')
fprintf(1,'%s %4.2f\n','Max. Froude:',MaxFroude)
fprintf(1,'%s %4.2f\n','Avg. Froude:', AvgFroude)
% write RSE to console by intervals
for j=1:length(gradOut.midint);
    fprintf(1,'%s %4.1f %s %4.1f %s %4.2f \n','RSE for interval',...
        matIn.mindepth(j), '-', matIn.maxdepth(j),...
        'cm : ', results.RSE(j))    
end
fprintf(1,'%s %4.2f \n','RSE for the entire layer is ',...
        results.mean_RSE)
fprintf(1,'%s %5.2f %5.2f\n','Phi Range is ', matIn.PHIrange);
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% MB EDIT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%write output structure
modelOUT.modelP=modelP;
modelOUT.siteInfo=siteInfo;
modelOUT.datain=datain;
modelOUT.details=details;
modelOUT.results=results;

if exist('gradOut', 'var')
    modelOUT.gradOut=gradOut;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%subfunctions------------------------------------------------------------------------------

function [gradOut]=grading(sl,phi,z,intv,porosity)

% grading.m- X A matlab program to calculate grading of sediment based on
%             concentration profiles for different grain size classes.
%
%   function [m1,stdev,fwmean, fwsort,fwskew,fwkurt]=grading(sl,phi,z,intv,porosity)
%             
%   Input: sl- Sediment load for each size class (columns) for given z (rows).
%          phi- size classes in phi (# classes = columns of C), row vector
%          z- elevation (m) above bottom of sediment loads, (# elevations =
%             rows of sl), column vector
%          intv- interval (m) of sediment texture stats- may be a set interval or
%                a vector with all intervals except 0 and thickness
%                specified (e.g.; thickness 1 cm, 2 cm, 1 cm, 4 cm
%                intv=[0.01 0.03 0.04 0.08])
%                default is 0.01 m if not specified
%          porosity- porosity of deposit, default is 0.35 if not specified
%
%  functions used:  tubesetvel.m, sedstats.m
%
%   written 9/29/03 by Bruce Jaffe

% set defaults for intervals and porosity if not specified


[hrow,sclass]=size(sl);  % determine matrix size
hitsize=zeros(hrow*sclass,1); % initiate array with size of particles hitting bed
hitload=zeros(hrow*sclass,1); % initiate array with concentration of particles hitting bed
hitheight=zeros(hrow*sclass,1); % initiate array with height of particles hitting bed

if (length(z)~=hrow) || (length(phi)~=sclass)
   'Number of size classes or number of elevations do not match profiles';
end
z=z(:);     % z must be a column vector

% calculate time for sediment to reach reach bottom
setvel=0.01*tubesetvel(phi);        % calculate settling velocity (m/s) 

[m,n]=size(setvel);
if m>n
    setvel=setvel'; % make sure setvel is a row vector
end
settlingtime=z(:,ones(1,sclass))./setvel(ones(1,hrow),:);  % calculate settling time (s)          
stime=settlingtime(:);   % first make profiles into a column vector to sort all values

% sort by time it takes to hit bottom
[hittime,ind]=sort(stime);            % hittime is sorted column vector, ind is column vector of indices

% find size of sediment hitting the bed
phiind=floor((ind-0.001)/hrow)+1;   % find size of sediment
hitsize=phi(phiind);    % keep track of order sediment size hitting the bed 

% find elevations that sediment started from 
zind=rem(ind,hrow);
lastz=find(zind==0);  % find cells with last height improperly set to 0
zind(lastz)=hrow;  % reset indices to correct last height
hitheight=z(zind); % keep track of order of height sediment came from

for i=1:length(zind);
    hitload(i)=sl(zind(i),phiind(i));      % keep track of concentration of sediment hitting bed
end

thickness=cumsum(hitload)./(1-porosity);    % cumulative thickness of deposit

if length(intv)==1  % calculate interval boundaries for set intervals
    
% determine interval breaks
    for intbound=intv:intv:thickness(length(thickness))-intv/2;
        intbind(round(intbound/intv))=max(find(thickness<intbound));
    end  
    
    intbind=[1 intbind length(thickness)]; % add break at first and last thickness value
        
else % if interval boundaries are specified
    for intbound=1:length(intv);
        intbind(intbound)=max(find(thickness<intv(intbound))); 
    end
    intbind=[1 intbind]
end


% calculate stats for each interval

st=intbind(1:length(intbind)-1);
last= intbind(2:length(intbind));

for j=1:length(st);
    for k=1:length(phi);         % get cumulative sediment loads for each phi class
        sload(k)=sum(hitload(st(j)-1+find(hitsize(st(j):last(j))==phi(k))));   
    end
   [m1(j),stdev(j),m3(j),m4(j),fwmedian(j),fwmean(j),fwsort(j),fwskew(j),fwkurt(j)]= ...
   sedstats(phi,sload);
   p(j,:)=phi;
   s(j,:)=sload;
   wpc(j,:)=100*sload./(sum(sload));  % weight percent in each phi interval (added 4/29/08 per Rob's request)
end
  
midint=(thickness(st)+thickness(last))/2;

set(0,'units','pixels');ssize=get(0,'screensize');
lp=round(ssize(3)*0.2);
bp=round(ssize(4)*0.1);
wp=round(ssize(3)*0.6);
hp=round(ssize(4)*0.8);

hfig=figure('position',[lp bp wp hp]);

titler={'Grain Statistics, 1st Moment for layers';...
    'Grain Statistics, Standard Deviation for layers';...
    'Grain Statistics, FW mean for layers';...
    'Grain Statistics, FW sorting for layers';...
    'Grain Statistics, FW Skewness for layers';...
    'Grain Statistics, FW Kurtosis for layers';...
    'Thickness vs. Time sediment hits bottom'};

xlabelr={'1st Moment (phi)';...
    'Standard Deviation (phi)';...
    'FW Mean (phi)';...
    'Sorting (phi)';...
    'Skewness';...
    'Kurtosis';...
    'Time(s)'};


ylabelr={'Midpoint of Layer (m)';...
    'Midpoint of Layer (m)';...
    'Midpoint of Layer (m)';...
    'Midpoint of Layer (m)';...
    'Midpoint of Layer (m)';...
    'Midpoint of Layer (m)';...
    'Thickness (m)'};

gradD.list1=uicontrol('style','popup',...
    'units','normalized','position',[0.1 0 0.35 0.05],...
    'string',titler,'callback',@updatePlot);

gradD.ax1=axes;
gradD.p1=plot(m1,midint,'.-','linewidth',2);
gradD.title=title('Grain Statistics, 1st Moment for layers',...
    'fontsize',16);
gradD.xlabel=xlabel('1st Moment (phi)','fontsize',14);
gradD.ylabel =ylabel('Midpoint of Layer (m)','fontsize',14);

pos=get(gradD.ax1,'position');
pos(1)=pos(1)+0.2*pos(3);
pos(2)=pos(2)+0.1*pos(4);
pos(3)=0.6*pos(3);
pos(4)=0.8*pos(4);
set(gradD.ax1,'fontsize',12)

gradD.m1=m1;
gradD.stdev=stdev;
gradD.fwmean=fwmean;
gradD.fwsort=fwsort;
gradD.fwskew=fwskew;
gradD.fwkurt=fwkurt;
gradD.hittime=hittime;
gradD.thickness=thickness;
gradD.midint=midint;
gradD.titler=titler;
gradD.xlabelr=xlabelr;
gradD.ylabelr=ylabelr;

gradOut.midint=midint;
gradOut.m1=m1;
gradOut.stdev=stdev;
gradOut.fwmean=fwmean;
gradOut.fwsort=fwsort;
gradOut.fwskew=fwskew;
gradOut.fwkurt=fwkurt;
gradOut.hittime=hittime;
gradOut.thickness=thickness;
gradOut.p=p;
gradOut.s=s;
gradOut.wpc=wpc;
guidata(hfig,gradD);

%%%% GUI callback %%-----------------------------------------
function updatePlot(hfig,eventdata,handles)

gradD=guidata(hfig);
gradD.dtype=get(gradD.list1,'value');

switch gradD.dtype
    case 1
        set(gradD.p1,'xdata',gradD.m1);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
        
    case 2
        set(gradD.p1,'xdata',gradD.stdev);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
    case 3
        set(gradD.p1,'xdata',gradD.fwmean);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
    case 4
        set(gradD.p1,'xdata',gradD.fwsort);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
    case 5
        set(gradD.p1,'xdata',gradD.fwskew);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
    case 6
        set(gradD.p1,'xdata',gradD.fwkurt);
        set(gradD.p1,'ydata',gradD.midint);
        set(gradD.ax1,'xscale','linear');
    case 7
        set(gradD.p1,'xdata',gradD.hittime);
        set(gradD.p1,'ydata',gradD.thickness);
        set(gradD.ax1,'xscale','log');
end

set(gradD.title,'string',gradD.titler{gradD.dtype});
set(gradD.xlabel,'string',gradD.xlabelr{gradD.dtype});
set(gradD.ylabel,'string',gradD.ylabelr{gradD.dtype});

%%%%----------------------------------------------------------
function [m1,stdev,m3,m4,fwmedian,fwmean,fwsort,fwskew,fwkurt]=sedstats(phi,weight)

% sedstats.m-  a function compute moment measures and Folk and Ward statistics from 
%                 sediment grain size weight % and phi size classes.
%
%   function [m1,stdev,m3,m4,fwmedian,fwmean,fwsort,fwskew,fwkurt]=sedstats(phi,weight)
%
%   Inputs: phi- grain size (phi) for each size class
%           weight- weight (or weight percent, vol concentration) for size classes
%
%   Calculated: phimdpt- phi midpoints used for moment measures for tsunami samples, [-1.125:.25:10 12]
%          
%   Outputs: m1- mean grain size (phi), 1st moment
%            stdev- standard deviation (phi) similar to sorting, is equal to square root of 2nd moment
%            m3- third moment
%            m4- fourth moment
%            fwmedian- Folk and Ward medium grain size (phi), 50th percentile
%            fwmean- Folk and Ward mean grain size (phi)
%            fwsort- Folk and Ward sorting (phi)
%            fwskew- Folk and Ward skewness
%            fwkurt- Folk and Ward Kurtosis
%
%   References:  All formulas form sdsz version 3.3 documentation (dated
%   7/12/89).  Reference given for Folk and Ward statistics is:
%       Chapter 6, Mathematical Treatment of Size Distribution Data, Earle
%       F. McBride, University of Texas at Austin in Carver, R. E., 1971:
%       Procedures in Sedimentary Petrology: John Wiley and Sons, Inc., 653
%       pp.
%
%   written by Bruce Jaffe, 10/2/03

% calculate midpoint of size classes for use in moment measures


% make sure there are minimum of 2 size classes
if length(phi)==1;
    display('Moment measures not valid because there is only 1 size class');
    phi=[phi(1)-eps phi];                 % create a cumulative weight with 0% weight in it to allow calculation
end

mpt1=phi(1)+0.5*(phi(1)-phi(2));
phimdpt=[mpt1;phi(2:length(phi))+0.5*(phi(1:length(phi)-1)-phi(2:length(phi)))];
phimdpt=phimdpt';


% calculate the 1st moment (mean grain size)
m1=sum(phimdpt.*weight)/sum(weight);

dev=phimdpt-m1;

% calculate the standard deviation, similar to sorting, square root of the 2nd moment
var=sum(weight.*(dev.^2))/sum(weight);
stdev=sqrt(var);

% calculate the third moment
m3=sum(weight.*((dev/stdev).^3))/sum(weight);

% calculate the fourth moment
m4=sum(weight.*((dev/stdev).^4))/sum(weight);

% Use phi intervals, not midpoints to calculate Folk and Ward stats- for tsunami samples use [-1:.25:10 14]


cw=100*cumsum(weight)/sum(weight);          % calculate normalized cumulative weight percent

cp=[5 16 25 50 75 84 95];      % cumulative percents used in Folk and Ward statistics

if cw(1) >= 5;
    display('Folk and Ward Statistics suspect because first size class has >= 5% cumulative %')
    cw=[0 cw];                 % create a cumulative weight with 0% weight in it to allow calculation
end

% calculate cumulative percents used in Folk and Ward statistics using
% linear interpolation (could use different interpolation scheme)
for i=1:7;
lp=max(find(cw<cp(i)));
slp=(cp(i)-cw(lp))/(cw(lp+1)-cw(lp));
cumphi(i)=phi(lp)+slp*(phi(lp+1)-phi(lp));
end

% make some names that have meaning!
phi5=cumphi(1);
phi16=cumphi(2);
phi25=cumphi(3);
phi50=cumphi(4);
phi75=cumphi(5);
phi84=cumphi(6);
phi95=cumphi(7);

% calculate Folk and Ward stats
fwmedian=phi50;
fwmean=(phi16+phi50+phi84)/3;
fwsort=(phi84-phi16)/4+(phi95-phi5)/6.6;
fwskew=(phi16+phi84-2*phi50)/(2*(phi50-phi16))...
       +(phi5+phi95-2*phi50)/(2*(phi95-phi5));
fwkurt=(phi95-phi5)/(2.44*(phi75-phi25));
%%%%%---------------------------------------------------------

function [modelP,siteInfo,datain]=readModelFile(filename)
%READMODELFILE reads data from a standard excel
%spreadsheet and places info into three data
%structures
%
%INPUT: filename- filename of file to read.
%
%OUTPUT: modelP, siteInfo and datain are input
%parameters the model will run from

[data,hdr]=xlsread(filename);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Fix MAC ISSUE%%%%%%%%%%%%%
%Created by Mark Buckley Oct. 11, 2007

[row,col]=size(data);
data=data(2:row,:);  % Remove first row (TEXT ONLY)

if data(1,2)<10    % Check DATA Input
    display('Iterations<10: Check data matrix') 
end   

if data(1,2)>5000
    display('Iterations>5000: Check data matrix') 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

modelP.numIterations=data(1,2);
modelP.vonK=data(2,2);
modelP.numBins=data(3,2);
modelP.resuspCoeff=data(4,2);
modelP.concConvFac=data(5,2);
modelP.sizeConvFac=data(6,2);
modelP.shearVel=data(7,2);
if isnan(data(8,2))
    modelP.bedRoughness='auto';
else
    modelP.bedRoughness=data(8,2);
end
modelP.setType=data(9,2);
modelP.eddyViscShape=data(10,2);

siteInfo.name=hdr(14,2);
siteInfo.description=hdr(15,2);
siteInfo.depositThickness=data(15,2);
siteInfo.depth=data(16,2);
siteInfo.salinity=data(17,2);
siteInfo.waterTemp=data(18,2);
siteInfo.sedDensity=data(19,2);
siteInfo.bedConc=data(20,2);

lenHdr=length(hdr);

datain.phi=data(lenHdr:end,1);
datain.weights=data(lenHdr:end,2);
