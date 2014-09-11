%%
% This script is intended to be run with the working directory set to the
% location of the .xls file with the grain size data.
% all that is required in the directory is this run file
% and the grain size data. the directory with the inverse model and all subfolders
% must be added to your matlab path but need not be in the working directory.
%
% This script brings together all the files needed for to complete a model
% run. It also allows some model run options to be specified. It writes an
% output file with model inputs and outputs. It creates some plots of model
% results.
%%
clear all; close all;
%Save figures?
Save.ALL=1;  % put 0 if don't want to save files
%Save figure path
fpath = fullfile(pwd, 'Figures');
if ~exist(fpath)
    mkdir(fpath);
end

%Site data file name
fname='Japan_Site_Data_interp_T3_Jogan.xls'; %Default .xls file IN CURRENT WORKING DIRECTORY

% path to model run file
inv_model_name = 'Tsunami_InvVelModel_V3p7MB';
[inv_model_path, ~, ~] = fileparts(which(inv_model_name));
% path to file specifying default model parameters
% if not using default model parameters, save model parameters file in pwd
% and use:
% inv_modelP_file = fullfile(pwd,'Name_Of_Non_Default_Model_Params_File.xls');
inv_modelP_file = fullfile(inv_model_path, 'Tsunami_InvVelModel_Default.xls');

%Site Name
sname='T3';
%Use to look at specific trenchs
Trench_ID=[{'T3-16'}];
%Depth range  *** change to look at different intervals of the deposit
Drange=[10 14];
%Phi range
PHIrange=[-1 7];

%set which input file reader to use
%   2 = SED_Size_Reader_02.m
%   3 = SED_Size_Reader_03.m
%   0 = uniform_GS_csv_reader.m
rdr = 2;
%Run SED_Size_Reader
if rdr == 2
    [SedSize]=...
        SED_Size_Reader_02('infile',[fname],'Trench_ID',Trench_ID,'Drange',Drange,'PHIrange',PHIrange);
elseif rdr == 3
    [SedSize]=...
        SED_Size_Reader_03('infile',[fname],'Trench_ID',Trench_ID,'Drange',Drange,'PHIrange',PHIrange);
elseif rdr == 0
    % not yet implemented
    [SedSize]=...
        uniform_GS_csv_reader('infile',[fname],'Drange',Drange,'PHIrange',PHIrange);        
end
%%%
%Take what you need from SED_size_reader
matIn.phi=SedSize.phi;
matIn.wt=SedSize.Bulk.wt;
matIn.th=(max(SedSize.maxdepth)-min(SedSize.mindepth))/100;
%%
%Set parameter value if you want to loop and run inverse model
% If value not specified, then goes to defaults in
% Tsunami_InvVelModel_Default.xls
%added varargin options in V3p6:
% 'matIn'            structure to read in phi,wt,thickness
% 'h'                flow depth
% 'zotot'            specify a total bed roughness parameter
% 'mannings'         specify a mannings n component of bed roughness (model will calculate total
% 'th'               thickness (will not work for distribution comparison)
% 'eddyViscShape'   
% function
% 'rhow'

% values to loop through for model runs
param=[0.02 0.03 0.04];   

% open file to write output
out_file_name = ['Inv-V3p7_results_',SedSize.Tname,'_',num2str(Drange(1)),...
                '-',num2str(Drange(2)),'cm_','model_output.csv'];
out_file_path = fullfile(pwd, out_file_name);

if exist(out_file_path)
    fid=fopen(out_file_path,'a');
else
    fid = fopen(out_file_path, 'w');
    fprintf(fid, repmat('%s,', 1, 27), 'trench_id', 'min_depth_cm', 'max_depth_cm',...
            'param', 'model_name', 'date_time', 'run_time', 'iterations',...
            'description', 'phi_min', 'phi_max', 'deposit_thickness_m',...
            'flow_depth_m', 'N_size_classes', 'mean_grain_diameter_m',...
            'eddy_viscosity_profile', 'ustarc_mps', 'zo_tot', 'thload_m',...
            'predict_ss_load_m', 'max_speed_mps', 'avg_speed_mps', 'max_froude',...
            'avg_froude', 'interval', 'total_intervals', 'rms_error');
    fprintf(fid,'\n');
end
% format string for writing csv file
f_str='%s,%4.2f,%4.2f,%4.3f,%s,%s,%4.2f,%i,%s,%4.2f,%4.2f,%4.3f,%4.2f,%i,%.3e,%s,%4.2f,%.3e,%4.3f,%4.3f,%5.2f,%5.2f,%4.2f,%4.2f,%i,%i,%4.2f,\n';
     
% loop through param values, running model with each value
for i=1:length(param)
     
    [modelOUT(i)]=Tsunami_InvVelModel_V3p7MB...
        ('infile',inv_modelP_file,'grading',0.01,'matIn',matIn,'zotot',param(i),'h',0.5,'sname',sname,'eddyViscShape',3);
    
    AvgSpeed(i,1)=modelOUT(i).results.AvgSpeed;
    AvgFroude(i,1)=modelOUT(i).results.AvgFroude;
    
    %     Calculate RMS error between modeled and observed distributions for each 1-cm (or other) interval in suspension graded layer
    %     calculated for only the 1st model parameter
    FlipSedWt=fliplr(SedSize.wt)*100;  %flip so order of levels in observed and modeled wts match
    for j=1:length(modelOUT(1).gradOut.midint);
        RmsError(i,j)=sqrt(sum(((FlipSedWt(:,j))'-modelOUT(i).gradOut.wpc(j,:)).^2))/numel(modelOUT(i).gradOut.wpc(j,:));

        % write out the RMS errors
        fprintf(1,'%s %4.2f %s %i %s %4.2f \n','RMS error for ',param(i), 'interval', j, ' : ', RmsError(i,j))

    end
    MeanRmsError(i)=mean(RmsError(i,:));
    fprintf(1,'%s %4.2f %s %4.2f \n','RMS error for ',param(i), 'for the entire layer is ',MeanRmsError(i))
    fprintf(1,'%s %5.2f %5.2f\n','Phi Range is ',PHIrange);
   
    % write an output file, with one entry for each calculated RMS error
    n_intervals = length(modelOUT(1).gradOut.midint);
    for jj=0:n_intervals;
        if jj == 0
            rms = MeanRmsError(i);
        else
            rms = RmsError(i, jj);
        end
        fprintf(fid, f_str, SedSize.Tname, Drange(1), Drange(2), param(i),...
                inv_model_name, modelOUT(i).details.timestamp,...
                modelOUT(i).details.elapsed_time, modelOUT(i).details.iterations,...
                char(modelOUT(i).siteInfo.description), PHIrange(1), PHIrange(2),...
                modelOUT(i).siteInfo.depositThickness, modelOUT(i).siteInfo.depth,...
                modelOUT(i).details.n_sedsize_class, modelOUT(i).details.mean_grain_diameter_m,...
                modelOUT(i).details.eddy_viscosity_profile, modelOUT(i).results.ustrc,...
                modelOUT(i).results.zotot, modelOUT(i).results.thload,...
                modelOUT(i).results.predicted_ss_load, modelOUT(i).results.MaxSpeed,...
                modelOUT(i).results.AvgSpeed, modelOUT(i).results.MaxFroude,...
                modelOUT(i).results.AvgFroude, jj, n_intervals, rms);
    end
    
    close;  % closes Tsunami_InvVelModel_V3p6 figures  get rid of close if you want those figures
    
end

fclose(fid);

%% Speed and Froude number plot
%close all;clc; Mark closes all figures and clear the command line for
%running in cells
subplot(1,2,1)
plot(param,AvgSpeed);
box on; grid on;


xlabel('Parameter value');
ylabel('AvgSpeed (m/s)');
subplot(1,2,2)
plot(param,AvgFroude);
box on; grid on;
xlabel('Parameter value');
ylabel('AvgFroude');
% change if you want to resize figures
set(gcf, 'PaperPositionMode', 'manual','PaperUnits','inches','units','inches',...
    'position',[1 1 6 5], 'PaperPosition', [0 0 6 5])

% change -r300 to up the dpi; e.g., -r600 is 600 dpi
% to change file type to editable in illustrator change '-djpeg' to
% '-depsc' or '-dill'
if Save.ALL==1
    print('-r300','-djpeg', fullfile(fpath, ['Results_',...
        char(SedSize.Tname),'_',num2str(Drange(1)),'-',num2str(Drange(2)),'cm_gelf']))
end
%% Stack plot: Distribution
%close all;clc; Mark closes all figures and clear the command line for
%running in cells
max_shift=50;  % change if distributions are overlapping vert.  default 25
%Plot: Image with stats
figure('name',['Plot: Image with stats: ' sname '_' SedSize.Tname]); hold on;
for tt=1:length(SedSize.phi)
    temp=0:max_shift:(length(SedSize.wt(1,:))-1)*max_shift;
    ttemp(tt,:)=temp;
end
% Bruce changed plotting to data marked with dots and model a line
if length(SedSize.Sample_ID)>1
    plot(SedSize.phi,fliplr(fliplr(SedSize.wt)*100+ttemp),'.')%flipped to make lengend work better
    for i=1:length(param)
        if i==1;
            plot(SedSize.phi,(modelOUT(i).gradOut.wpc)'+ttemp,'m')%flipped to make lengend work better
        elseif i==2
            plot(SedSize.phi,(modelOUT(i).gradOut.wpc)'+ttemp,'c')%flipped to make lengend work better
        else
            plot(SedSize.phi,(modelOUT(i).gradOut.wpc)'+ttemp,'k')%flipped to make lengend work better
        end
    end
    title([sname ': ' SedSize.Tname])
    ylim([0 (length(SedSize.Sample_ID))*max_shift])
    if length(SedSize.Sample_ID)<15
        set(gca,'ytick',[0:max_shift/2:(length(SedSize.Sample_ID))*max_shift],'yticklabel',[0 max_shift/2],'Ygrid','on')
    else
        set(gca,'ytick',[0:max_shift:(length(SedSize.Sample_ID))*max_shift],'yticklabel',[],'Ygrid','on')
    end
    xlabel('Grain Size [phi]')
    ylabel('weight %')
    t= legend(SedSize.range,'orientation','vertical','location','eastoutside');
    set(get(t, 'title'), 'String' , 'Depth [cm]');
    grid on
    box on
    % sets display and print size  of figure
    set(gcf, 'PaperPositionMode', 'manual','PaperUnits','inches','units','inches',...
        'position',[1 1 8 10], 'PaperPosition', [1 1 4 5])

    if Save.ALL==1
        %print('-r200','-djpeg',['Stack_',...
            print('-r600','-depsc', fullfile(fpath, ['Stack_',...
            char(SedSize.Tname),'_',num2str(Drange(1)),'-',num2str(Drange(2)),'cm_gelf']))
    end
end
%%
% looking at concentration profiles
Cfig=0;
if Cfig==1
    figure
    plot(modelOUT(1).details.C,modelOUT(1).details.z)
    figure
    semilogx(modelOUT(1).details.C,modelOUT(1).details.z);xlim([0,0.01])
end
%%
% plotting distributions observed together, modeled distribution together
% plot observed distributions
ObsDist=1;
if ObsDist==1
    figure
    plot(SedSize.phi,fliplr(fliplr(SedSize.wt)*100))
    title([sname ': ' SedSize.Tname ' Observed Distributions'])
    ylim([0 30]) % default is 25 for Wt. percent, can change
   % if length(SedSize.Sample_ID)<15
   %     set(gca,'ytick',[0:max_shift/2:(length(SedSize.Sample_ID))*max_shift],'yticklabel',[0 max_shift/2],'Ygrid','on')
   % else
   %    set(gca,'ytick',[0:max_shift:(length(SedSize.Sample_ID))*max_shift],'yticklabel',[],'Ygrid','on')
   % end
    xlabel('Grain Size [phi]')
    ylabel('weight %')
    t= legend(SedSize.range,'orientation','vertical','location','eastoutside');
    set(get(t, 'title'), 'String' , 'Depth [cm]');clear figures
    
    box on
    % sets display and print size  of figure
    set(gcf, 'PaperPositionMode', 'manual','PaperUnits','inches','units','inches',...
        'position',[1 1 8 10], 'PaperPosition', [1 1 4 5])

    if Save.ALL==1
        print('-r600','-depsc', fullfile(fpath, ['Observed_Dists_',...
            char(SedSize.Tname),'_',num2str(Drange(1)),'-',num2str(Drange(2)),'cm_gelf']))
    end
end

%%
% plot modeled distributions
ModDist=0;
if ModDist==1
    figure
    plot(SedSize.phi,flipud(modelOUT.gradOut.wpc))
    title([sname ': ' SedSize.Tname ' Modeled Distributions'])
    ylim([0 25])
    xlabel('Grain Size [phi]')
    ylabel('% weight')
    t= legend(SedSize.range,'orientation','vertical','location','eastoutside');
    set(get(t, 'title'), 'String' , 'Depth [cm]');
    box on
    % sets display and print size  of figure
    set(gcf, 'PaperPositionMode', 'manual','PaperUnits','inches','units','inches',...
        'position',[1 1 8 10], 'PaperPosition', [1 1 4 5])

    if Save.ALL==1
        print('-r600','-depsc', fullfile(fpath, ['Modeled_Dists_',...
            char(SedSize.Tname),'_',num2str(Drange(1)),'-',num2str(Drange(2)),'cm_gelf']))
    end
end

%%
% plot deposit formation history
LayerForm=1;
if LayerForm==1
    figure
    semilogx(gradingD.hittime,gradingD.thickness)
    title([sname ': ' SedSize.Tname ' Layer Formation ' num2str(Drange(1)),'-',num2str(Drange(2)) ' cm'])
    ylim([0 max(gradingD.thickness)])
    xlabel('Time [s]')
    ylabel('Thickness [m]')
   
    % sets display and print size  of figure
    set(gcf, 'PaperPositionMode', 'manual','PaperUnits','inches','units','inches',...
        'position',[1 1 8 10], 'PaperPosition', [1 1 4 5])

    if Save.ALL==1
        print('-r600','-depsc', fullfile(fpath, ['Layer-Formation_',...
            char(SedSize.Tname),'_',num2str(Drange(1)),'-',num2str(Drange(2)),'cm_gelf']))
    end
end