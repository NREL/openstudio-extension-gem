//Jenkins pipelines are stored in shared libaries. Please see: https://github.com/tijcolem/nrel_cbci_jenkins_libs 
 
@Library('cbci_shared_libs') _

// Build for PR to develop branch only. 
if ((env.CHANGE_ID) && (env.CHANGE_TARGET) ) { // check if set

  openstudio_extension_gems_3_x()
    
}
