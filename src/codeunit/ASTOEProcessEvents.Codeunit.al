codeunit 78352 "AST OE Process Events"
{
    // Publishes integration events for upcoming process implementations.
    [IntegrationEvent(false, false)]
    procedure OnAfterCreateExpeditionFromServItemJournal(var ServItemJournal: Record "AST Serv. Item Entry Journal"; var ExpeditionHeader: Record "ASTEX Expedition"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnBeforeInsertExpeditionLineFromServItemJournal(var ExpeditionLine: Record "ASTEX Expeditions Lines"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    procedure OnBeforeInsertRouteExpeditionLineFromServItemJournal(var RouteExpeditionLine: Record "ASTEX Route Expedition Lines"; var IsHandled: Boolean)
    begin
    end;

}