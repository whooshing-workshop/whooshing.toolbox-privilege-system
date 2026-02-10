import PrivilegeModule

protocol SystemController: Controller where E == PrivilegeSystem.Errcase {}

protocol SystemOPAController: OPAController where E == PrivilegeSystem.Errcase {}
